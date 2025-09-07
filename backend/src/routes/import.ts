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
import fetch from "node-fetch";
import "dotenv/config";
import { addImportJob, getJobStatus, maybeStartWorker } from "../queue/queue.ts";
import type { Job } from 'bullmq';
import { ImportService as ISvc } from "../services/importService.ts";
import { importPresetsCollection } from "../database/importPresets.ts";
import { rulesCollection } from "../database/rules.ts";

export const importRouter = Router();

// Start background worker if enabled (requires REDIS_URL and RUN_QUEUE_WORKER=true)
 

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

// --- AI helpers (OpenAI) ---
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_BASE = process.env.OPENAI_BASE_URL || "https://api.openai.com/v1";
const OPENAI_MODEL_JSON = process.env.OPENAI_MODEL_JSON || "gpt-4o-mini";

async function openaiClassify(entries: { description: string; merchant?: string }[]) {
  if (!OPENAI_API_KEY || !entries.length) return [] as any[];
  const system = `You normalize merchants and categorize bank transactions. 
Return JSON with an array 'items' matching inputs order. Each item: { merchant: canonical brand name (e.g., "Walmart"), category: one of [Food, Transportation, Shopping, Bills, Entertainment, Health, Other], confidence: 0..1 }.
Be conservative and avoid overfitting.`;
  const user = JSON.stringify({ inputs: entries });
  const resp = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${OPENAI_API_KEY}` },
    body: JSON.stringify({
      model: OPENAI_MODEL_JSON,
      messages: [ { role: "system", content: system }, { role: "user", content: user } ],
      response_format: { type: "json_object" },
      temperature: 0.2,
    }),
  });
  if (!resp.ok) {
    const text = await resp.text();
    console.error("openai classify error", resp.status, text);
    return [] as any[];
  }
  const data: any = await resp.json();
  const content = data.choices?.[0]?.message?.content || "{}";
  try {
    const parsed = JSON.parse(content);
    return Array.isArray(parsed.items) ? parsed.items : [];
  } catch {
    return [] as any[];
  }
}

function heuristicNormalizeMerchant(desc: string): string {
  let s = desc.toLowerCase();
  // remove noise tokens
  s = s.replace(/\b(pos|purchase|check ?card|visa|debit|credit|payment|auth|id)\b/gi, " ");
  // remove store numbers and hashes
  s = s.replace(/#?\d{3,}/g, " ");
  // remove city/state suffixes (simple heuristic)
  s = s.replace(/\b([A-Z]{2})\b/g, " ");
  // common chains mapping
  const map: [RegExp, string][] = [
    [/walmart|wal\s*mart/i, "Walmart"],
    [/target/i, "Target"],
    [/costco/i, "Costco"],
    [/kroger/i, "Kroger"],
    [/safeway/i, "Safeway"],
    [/amazon/i, "Amazon"],
    [/starbucks/i, "Starbucks"],
    [/mcdonald/i, "McDonald's"],
    [/chipotle/i, "Chipotle"],
    [/shell/i, "Shell"],
    [/chevron/i, "Chevron"],
    [/exxon/i, "Exxon"],
    [/netflix/i, "Netflix"],
    [/spotify/i, "Spotify"],
    [/apple\s*(store|services)?/i, "Apple"],
    [/google/i, "Google"],
  ];
  for (const [re, name] of map) if (re.test(desc)) return name;
  // fallback: first non-generic word capitalized
  const tokens = s.replace(/[^a-z\s]/g, "").split(/\s+/).filter(Boolean);
  const blacklist = new Set(["store","market","super","supermarket","gas","fuel","restaurant","cafe","co","inc"]);
  const t = tokens.find((w) => !blacklist.has(w));
  return t ? t.charAt(0).toUpperCase() + t.slice(1) : desc.trim();
}

async function enrichWithAI(rows: any[]) {
  // Build unique descriptions to reduce tokens
  const uniq = Array.from(new Set(rows.map((r) => String(r.description || "").trim()).filter(Boolean)));
  // Prepare entries with heuristic merchant for context
  const entries = uniq.slice(0, 200).map((d) => ({ description: d, merchant: heuristicNormalizeMerchant(d) }));
  const results = await openaiClassify(entries);
  const map = new Map<string, { merchant?: string; category?: string; confidence?: number }>();
  for (let i = 0; i < entries.length; i++) {
    const input = entries[i].description;
    const r = results[i] || {};
    map.set(input, { merchant: r.merchant || entries[i].merchant, category: r.category, confidence: r.confidence });
  }
  // Apply back to rows
  for (const r of rows) {
    const key = String(r.description || "").trim();
    const m = map.get(key);
    if (m) {
      (r as any).merchantCanonical = m.merchant || heuristicNormalizeMerchant(key);
      (r as any).categorySuggested = m.category;
      (r as any).categoryConfidence = typeof m.confidence === "number" ? m.confidence : undefined;
    } else {
      (r as any).merchantCanonical = heuristicNormalizeMerchant(key);
    }
  }
  return rows;
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

function isDiscoverMapping(mapping: ColumnMapping): boolean {
  const d = (mapping.date || "").toLowerCase();
  const desc = (mapping.description || "").toLowerCase();
  const amt = (mapping.amount || "").toLowerCase();
  return d.includes("trans. date") && desc === "description" && amt === "amount";
}

function sniffDelimiter(firstLine: string): string {
  const counts = {
    ",": (firstLine.match(/,/g) || []).length,
    ";": (firstLine.match(/;/g) || []).length,
    "\t": (firstLine.match(/\t/g) || []).length,
  };
  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
}

function columnsSignature(cols: string[]): string {
  const key = cols.map(c => c.toLowerCase().trim()).sort().join('|')
  return crypto.createHash('sha1').update(key).digest('hex')
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
    // Avoid logging full headers to prevent leaking Authorization
    const { "content-type": ct, "content-length": cl } = req.headers as any;
    console.log("➡️ /api/import/preview PRE", { contentType: ct, contentLength: cl });
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

      let preview = parsed.preview;

      // Discover: filter out incomes (payments/credits)
      if (isDiscoverMapping(mapping)) {
        preview = preview.filter((tx: any) => (tx.type || "expense") === "expense");
      }

      // Enrich with AI (normalize + categorize) if key present
      try {
        preview = await enrichWithAI(preview);
      } catch (e) {
        console.warn("AI enrichment skipped (preview)", e);
      }

      // Lightweight duplicate estimate using recent hashes (if available) or field comparison
      const col = await transactionsCollection();
      const recent = await col
        .find({ userId: new ObjectId(userId) })
        .project({ dedupeHash: 1, date: 1, amount: 1, amountCents: 1, note: 1 })
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
          (r) => {
            const rAmt = (r as any).amountCents ? (r as any).amountCents/100 : (r as any).amount;
            return (
              r.date.toISOString().slice(0, 10) === tx.date &&
              Math.abs(rAmt - tx.amount) < 0.01 &&
              (r.note ?? "").toLowerCase().trim() === tx.description.toLowerCase().trim()
            );
          }
        );
      });

      return res.json({
        previewRows: preview,
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

      // Async path using queue if requested and Redis configured
      const doAsync = String(req.query.async || req.body.async || "false").toLowerCase() === "true";
      if (doAsync) {
        const qid = await addImportJob({
          userId,
          fileBufferBase64: req.file.buffer.toString('base64'),
          mapping,
          kind,
          options: { skipDuplicates, overwriteDuplicates, useAI: String(req.body.ai || req.body.useAI || "true").toLowerCase() !== "false", applyAICategory: String(req.body.applyAICategory || "false").toLowerCase() === "true" }
        }).catch(() => undefined);
        if (!qid) return res.status(503).json({ error: 'queue_unavailable' });
        return res.json({ queued: true, jobId: qid });
      }

      // Parse FULL file once (inline)
      let { rows, totalRows, errors } = await ImportService.parse(
        req.file.buffer,
        { mapping, kind }
      );

      // Discover: filter out incomes (payments/credits)
      if (isDiscoverMapping(mapping)) {
        rows = rows.filter((tx: any) => (tx.type || "expense") === "expense");
      }

      // Optional AI enrichment for commit
      const useAI = String(req.body.ai || req.body.useAI || "true").toLowerCase() !== "false";
      const applyAICategory = String(req.body.applyAICategory || "false").toLowerCase() === "true";
      if (useAI) {
        try {
          rows = await enrichWithAI(rows);
          if (applyAICategory) {
            // Apply suggested category when original missing
            rows = rows.map((r: any) => ({
              ...r,
              category: r.category || r.categorySuggested || r.category,
            }));
          }
        } catch (e) {
          console.warn("AI enrichment skipped (commit)", e);
        }
      }

      const col = await transactionsCollection();
      const userObjectId = new ObjectId(userId);

      // Apply user rules (category/tags) to parsed rows
      try {
        const rcol = await rulesCollection()
        const rules = await rcol.find({ userId: userObjectId, enabled: true }).sort({ order: 1, createdAt: 1 }).toArray()
        rows = rows.map((tx: any) => {
          for (const r of rules) {
            const fieldVal = String((tx as any)[r.when.field] || '')
            let match = false
            if (r.when.type === 'contains') match = fieldVal.toLowerCase().includes(r.when.value.toLowerCase())
            else if (r.when.type === 'regex') { try { match = new RegExp(r.when.value, 'i').test(fieldVal) } catch { match = false } }
            if (match) {
              if (r.set.category) tx.category = r.set.category
              if (Array.isArray(r.set.tags) && r.set.tags.length) {
                const cur = Array.isArray(tx.tags) ? tx.tags : []
                tx.tags = Array.from(new Set([...cur, ...r.set.tags])).slice(0, 20)
              }
              break
            }
          }
          return tx
        })
      } catch {}

      // Build bulk upserts with stable hash
      const ops = rows.map((tx: any) => {
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

// Simple job status endpoint
importRouter.get('/api/import/job/:id', requireAppJWT, async (req, res) => {
  try {
    const id = String(req.params.id);
    const status = await getJobStatus(id);
    res.json(status);
  } catch (e) {
    res.status(503).json({ error: 'queue_unavailable' });
  }
});

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

      const sig = columnsSignature(columns)
      // try find preset
      let preset: any = null
      try {
        const userId = new ObjectId(String((req as any).userId))
        preset = await (await importPresetsCollection()).findOne({ userId, signature: sig })
      } catch {}

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
        signature: sig,
        preset: preset ? { name: preset.name, mapping: preset.mapping } : undefined,
      });
    } catch (err) {
      console.error("Column detection error:", err);
      return res.status(500).json({ error: "Failed to detect columns" });
    }
  }
);

// Save an import preset
importRouter.post('/api/import/presets', requireAppJWT, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const { name, signature, mapping } = req.body ?? {}
    if (!name || !signature || !mapping) { res.status(400).json({ error: 'invalid_payload' }); return }
    const col = await importPresetsCollection()
    const now = new Date()
    const existing = await col.findOne({ userId, signature })
    if (existing) {
      await col.updateOne({ _id: existing._id }, { $set: { name, mapping, updatedAt: now } })
      const saved = await col.findOne({ _id: existing._id })
      res.json({ preset: { name: saved!.name, signature: saved!.signature, mapping: saved!.mapping } })
    } else {
      const r = await col.insertOne({ userId, name, signature, mapping, createdAt: now, updatedAt: now } as any)
      const saved = await col.findOne({ _id: r.insertedId })
      res.status(201).json({ preset: { name: saved!.name, signature: saved!.signature, mapping: saved!.mapping } })
    }
  } catch (e) {
    res.status(500).json({ error: 'save_preset_failed' })
  }
})

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
