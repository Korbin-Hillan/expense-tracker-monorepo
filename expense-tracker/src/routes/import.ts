// routes/importRouter.ts
import { Router } from "express";
import multer from "multer";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";
import { ImportService, ColumnMapping } from "../services/importService.ts";
import * as XLSX from "xlsx";
import { parse as csvParseSync } from "csv-parse/sync";
import crypto from "crypto";

export const importRouter = Router();

/** ---------- helpers ---------- */

type FileKind = "csv" | "xlsx" | "xls";

function detectKind(file: Express.Multer.File): FileKind | null {
  const name = file.originalname.toLowerCase();
  const mt = (file.mimetype || "").toLowerCase();
  if (
    name.endsWith(".csv") ||
    mt.includes("csv") ||
    mt === "application/vnd.ms-excel"
  )
    return "csv";
  if (name.endsWith(".xlsx") || mt.includes("spreadsheet")) return "xlsx";
  if (name.endsWith(".xls")) return "xls";
  return null;
}

// Stable dedupe hash (you can move this into ImportService and reuse)
function makeHash(tx: {
  accountId?: string;
  date: string;
  amount: number;
  description: string;
}) {
  const key = [
    tx.accountId ?? "",
    tx.date,
    tx.amount.toFixed(2),
    tx.description.toLowerCase().replace(/\s+/g, " ").trim(),
  ].join("|");
  return crypto.createHash("sha256").update(key).digest("hex");
}

// routes/importRouter.ts
function getMapping(body: any): ColumnMapping {
  const pick = (...c: (string | undefined)[]) =>
    c.find((x) => typeof x === "string" && x.trim().length > 0) ?? "";

  return {
    // ✅ prefer what the client sent; then common date headers
    date: pick(
      body.dateColumn,
      "Trans. Date",
      "Transaction Date",
      "Posted Date",
      "Post Date",
      "Date"
    ),
    description: pick(body.descriptionColumn, "Description", "Memo", "Details"),
    amount: pick(body.amountColumn, "Amount", "Debit", "Credit", "Value"),
    type: body.typeColumn,
    category: body.categoryColumn,
    note: body.noteColumn,
  };
}

function sniffDelimiter(firstLine: string): string {
  const counts = {
    ",": (firstLine.match(/,/g) || []).length,
    ";": (firstLine.match(/;/g) || []).length,
    "\t": (firstLine.match(/\t/g) || []).length,
  };
  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
}

/** ---------- multer ---------- */

// Keep memory storage for now; consider disk storage for big files.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // bump a bit; XLSX grows fast
  fileFilter: (req, file, cb) => {
    const ok =
      detectKind(file) !== null ||
      ["text/plain", "application/vnd.ms-excel", "text/csv"].includes(
        file.mimetype
      );
    cb(
      ok ? null : new Error("Invalid file type. Only CSV/XLSX/XLS allowed."),
      ok as any
    );
  },
});

/** ---------- /api/import/preview ---------- */

function requireMapping(m: ColumnMapping) {
  const missing = [
    !m.date?.trim() && "dateColumn",
    !m.description?.trim() && "descriptionColumn",
    !m.amount?.trim() && "amountColumn",
  ].filter(Boolean);
  if (missing.length) {
    const e: any = new Error(
      `Missing required column(s): ${missing.join(", ")}`
    );
    e.status = 400;
    throw e;
  }
}

importRouter.post(
  "/api/import/preview",
  (req, _res, next) => {
    console.log("➡️ /api/import/preview PRE headers:", req.headers);
    next();
  },
  requireAppJWT,
  upload.single("file"),
  (req, _res, next) => {
    console.log(
      "📦 multer finished. req.file?",
      !!req.file,
      "body keys:",
      Object.keys(req.body)
    );
    next();
  },
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      if (!req.file) return res.status(400).json({ error: "No file uploaded" });
      if (!ObjectId.isValid(userId))
        return res.status(400).json({ error: "Invalid user id" });

      const mapping = getMapping(req.body);
      console.log("🗺️ mapping from client:", mapping);
      requireMapping(mapping);

      const kind = detectKind(req.file);
      if (!kind)
        return res.status(400).json({ error: "Unsupported file format" });

      // Single parse call for a fast preview
      const parsed = await ImportService.parse(req.file.buffer, {
        mapping,
        kind,
        previewRows: 20,
      });
      console.log("🧪 preview totals", {
        totalRows: parsed.totalRows,
        previewRows: parsed.preview.length,
        errors: parsed.errors.length,
      });

      const preview = parsed.preview;

      // Lightweight duplicate estimate using recent hashes (if available) or field comparison
      const col = await transactionsCollection();
      const recent = await col
        .find({ userId: new ObjectId(userId) })
        .project({ dedupeHash: 1, date: 1, amount: 1, note: 1 })
        .sort({ date: -1 })
        .limit(5000)
        .toArray();

      const recentHashes = new Set(
        recent.filter((r) => r.dedupeHash).map((r) => r.dedupeHash as string)
      );

      const duplicates = preview.filter((tx) => {
        const hash = makeHash({
          date: tx.date,
          amount: tx.amount,
          description: tx.description,
        });
        if (recentHashes.size) return recentHashes.has(hash);
        // fallback if no hashes yet
        return recent.some(
          (r) =>
            r.date.toISOString().slice(0, 10) === tx.date &&
            Math.abs(r.amount - tx.amount) < 0.01 &&
            (r.note ?? "").toLowerCase().trim() ===
              tx.description.toLowerCase().trim()
        );
      });

      return res.json({
        previewRows: parsed.preview,
        totalRows: parsed.totalRows,
        errors: parsed.errors,
        duplicates,
        suggestedMapping: {
          // if you exposed suggestMapping in ImportService, call it here instead
          date: findBestColumn(Object.keys(preview[0] ?? {}), [
            "date",
            "transaction date",
            "posted date",
            "trans date",
            "post date",
          ]),
        },
      });
    } catch (err: any) {
      const status = err?.status ?? 500;
      console.error("Import preview error:", err);
      return res.status(status).json({ error: String(err.message || err) });
    }
  }
);

/** ---------- /api/import/commit ---------- */

importRouter.post(
  "/api/import/commit",
  requireAppJWT,
  upload.single("file"),
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      if (!req.file) return res.status(400).json({ error: "No file uploaded" });
      if (!ObjectId.isValid(userId))
        return res.status(400).json({ error: "Invalid user id" });

      const mapping = getMapping(req.body);
      const kind = detectKind(req.file);
      if (!kind)
        return res.status(400).json({ error: "Unsupported file format" });

      const skipDuplicates = req.body.skipDuplicates === "true";
      const overwriteDuplicates = req.body.overwriteDuplicates === "true";

      // Parse FULL file once
      const { rows, totalRows, errors } = await ImportService.parse(
        req.file.buffer,
        { mapping, kind }
      );

      const col = await transactionsCollection();
      const userObjectId = new ObjectId(userId);

      // Build bulk upserts with stable hash
      const ops = rows.map((tx) => {
        const dedupeHash = makeHash({
          date: tx.date,
          amount: tx.amount,
          description: tx.description,
        });
        const doc = ImportService.convertToTransactionDoc(
          tx,
          userObjectId,
          dedupeHash as any
        );
        return {
          updateOne: {
            filter: { userId: userObjectId, dedupeHash },
            update: overwriteDuplicates ? { $set: doc } : { $setOnInsert: doc },
            upsert: true,
          },
        };
      });

      const result = ops.length
        ? await col.bulkWrite(ops, { ordered: false })
        : { upsertedCount: 0, modifiedCount: 0 };
      const inserted = (result as any).upsertedCount ?? 0;
      const updated = overwriteDuplicates
        ? (result as any).modifiedCount ?? 0
        : 0;

      // If skipping duplicates and not overwriting, duplicatesSkipped = total - inserted
      const duplicatesSkipped =
        skipDuplicates && !overwriteDuplicates ? rows.length - inserted : 0;

      return res.json({
        success: true,
        totalProcessed: rows.length,
        inserted,
        updated,
        duplicatesSkipped,
        errors,
        summary: { totalRows },
      });
    } catch (err) {
      console.error("Import commit error:", err);
      return res.status(500).json({ error: "Import failed" });
    }
  }
);

/** ---------- /api/import/columns (POST: upload a file to inspect) ---------- */

importRouter.post(
  "/api/import/columns",
  requireAppJWT,
  upload.single("file"),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: "No file uploaded" });

      const kind = detectKind(req.file);
      if (!kind)
        return res.status(400).json({ error: "Unsupported file format" });

      let columns: string[] = [];
      let sheets: string[] = [];

      if (kind === "csv") {
        const head = req.file.buffer.slice(0, 256 * 1024).toString("utf8"); // peek first chunk
        const firstLine =
          head.split(/\r?\n/).find((l) => l.trim().length > 0) ?? "";
        const delimiter = sniffDelimiter(firstLine);

        const rows: any[] = csvParseSync(req.file.buffer, {
          bom: true,
          to: 1, // only header row
          relax_column_count: true,
          delimiter,
        });
        // rows[0] is array of header cells; handle quotes
        columns = Array.isArray(rows[0])
          ? rows[0].map((c: any) =>
              String(c ?? "")
                .replace(/"/g, "")
                .trim()
            )
          : [];
      } else {
        const wb = XLSX.read(req.file.buffer, { type: "buffer" });
        sheets = wb.SheetNames;
        if (sheets.length) {
          const sheet = wb.Sheets[sheets[0]];
          const aoa = XLSX.utils.sheet_to_json<any[]>(sheet, { header: 1 });
          columns = (aoa[0] ?? []).map((c) => String(c ?? "").trim());
        }
      }

      return res.json({
        columns,
        sheets,
        suggestedMapping: {
          date: findBestColumn(columns, [
            "date",
            "transaction date",
            "posted date",
            "trans date",
            "post date",
          ]),
          description: findBestColumn(columns, [
            "description",
            "memo",
            "details",
            "transaction",
            "merchant",
            "payee",
          ]),
          amount: findBestColumn(columns, [
            "amount",
            "debit",
            "credit",
            "value",
            "total",
            "$",
          ]),
          type: findBestColumn(columns, [
            "type",
            "transaction type",
            "debit/credit",
            "dr/cr",
          ]),
          category: findBestColumn(columns, [
            "category",
            "merchant category",
            "classification",
          ]),
          note: findBestColumn(columns, [
            "note",
            "memo",
            "reference",
            "check number",
          ]),
        },
      });
    } catch (err) {
      console.error("Column detection error:", err);
      return res.status(500).json({ error: "Failed to detect columns" });
    }
  }
);

/** ---------- helpers ---------- */

function findBestColumn(
  availableColumns: string[],
  searchTerms: string[]
): string | undefined {
  const norm = availableColumns.map((c) => c.toLowerCase().trim());
  for (const term of searchTerms) {
    const i = norm.findIndex((c) => c.includes(term));
    if (i >= 0) return availableColumns[i];
  }
  return undefined;
}
