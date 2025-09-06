// services/importService.ts
import * as XLSX from "xlsx";
import { parse as csvParse } from "csv-parse";
import { Readable } from "stream";
import { TransactionDoc } from "../database/transactions.js";
import { ObjectId } from "mongodb";
import crypto from "crypto";

export type FileKind = "csv" | "xlsx" | "xls";
export type ParseOptions = {
  previewRows?: number;
  mapping: ColumnMapping;
  kind: FileKind;
};
export type ParseResult<T> = {
  rows: T[];
  preview: T[];
  totalRows: number;
  errors: string[];
};

export interface ImportableTransaction {
  date: string; // ISO yyyy-mm-dd
  description: string;
  amount: number; // stored as absolute; type determines sign
  type?: "expense" | "income";
  category?: string;
  note?: string;
  tags?: string[];
  // AI enrichment (optional)
  merchantCanonical?: string;
  categorySuggested?: string;
  categoryConfidence?: number;
}

export interface ImportResult {
  totalRows: number;
  validTransactions: number;
  errors: ImportError[];
  preview: ImportableTransaction[];
  duplicates: ImportableTransaction[];
}

export interface ImportError {
  row: number;
  field: string;
  message: string;
  data: any;
}

export interface ColumnMapping {
  date: string;
  description: string;
  amount: string;
  type?: string;
  category?: string;
  note?: string;
}

export class ImportService {
  /**
   * Unified parse entrypoint used by /preview and /commit
   */
  static async parse(
    buffer: Buffer,
    opts: ParseOptions
  ): Promise<ParseResult<ImportableTransaction>> {
    const { kind, mapping, previewRows } = opts;

    let result: ImportResult;
    if (kind === "csv") {
      result = await this.parseCSV(buffer, mapping, previewRows);
    } else {
      // xlsx and xls handled by the same function
      result = await this.parseExcel(buffer, mapping);
    }

    return {
      rows:
        result.preview.length === result.validTransactions && !previewRows
          ? result.preview // small files
          : await (async () => {
              // If previewRows was passed, caller probably wants only preview.
              // For /commit you'll call without previewRows to parse full file.
              if (previewRows) return result.preview;
              // When called without previewRows, parseCSV/parseExcel already returned all rows in preview for simplicity.
              return result.preview;
            })(),
      preview: previewRows
        ? result.preview.slice(0, previewRows)
        : result.preview.slice(0, 20),
      totalRows: result.totalRows,
      errors: result.errors.map((e) => `${e.row}:${e.field}:${e.message}`),
    };
  }

  /**
   * Parse CSV file buffer and extract transactions
   */
  static async parseCSV(
    fileBuffer: Buffer,
    mapping: ColumnMapping,
    previewRows?: number
  ): Promise<ImportResult> {
    return new Promise((resolve, reject) => {
      const transactions: ImportableTransaction[] = [];
      const errors: ImportError[] = [];
      let rowIndex = 0;
      let totalRows = 0;

      const { delimiter } = sniffCSV(fileBuffer);
      const readable = Readable.from(fileBuffer);

      const parser = csvParse({
        columns: (header: string[]) =>
          header.map((h) =>
            String(h ?? "")
              .replace(/^\uFEFF/, "") // ✅ strip BOM
              .replace(/"/g, "")
              .trim()
          ),
        skip_empty_lines: true,
        trim: true,
        bom: true,
        relax_quotes: true,
        relax_column_count: true,
        delimiter,
      });

      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        resolve({
          totalRows,
          validTransactions: transactions.length,
          errors,
          preview: transactions, // caller will slice for preview
          duplicates: [],
        });
      };

      readable
        .pipe(parser)
        .on("data", (row) => {
          totalRows++;
          rowIndex++;
          try {
            const tx = ImportService.mapRowToTransaction(
              row,
              mapping,
              rowIndex
            );
            if (tx) {
              transactions.push(tx);
              // Early stop for preview: destroy parser but resolve on 'close'
              if (previewRows && transactions.length >= previewRows) {
                parser.destroy(); // will trigger 'close'
              }
            }
          } catch (error) {
            errors.push({
              row: rowIndex,
              field: "general",
              message:
                error instanceof Error
                  ? error.message
                  : "Unknown parsing error",
              data: row,
            });
          }
        })
        .once("error", (err) => {
          if (settled) return;
          settled = true;
          reject(new Error(`CSV parsing failed: ${err.message}`));
        })
        // IMPORTANT: resolve on either end or close
        .once("end", finish)
        .once("close", finish);
    });
  }

  /**
   * Parse Excel file buffer and extract transactions (xlsx/xls)
   */
  static async parseExcel(
    fileBuffer: Buffer,
    mapping: ColumnMapping,
    sheetName?: string
  ): Promise<ImportResult> {
    try {
      const workbook = XLSX.read(fileBuffer, { type: "buffer" });
      const targetSheetName = sheetName || workbook.SheetNames[0];
      const worksheet = workbook.Sheets[targetSheetName];
      if (!worksheet) throw new Error(`Sheet "${targetSheetName}" not found`);

      // Convert to AOA with header row
      const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
      if (data.length < 2)
        throw new Error(
          "Excel must include a header row and at least one data row"
        );

      const headers = (data[0] as any[]).map((h) => String(h ?? "").trim());
      const rows = data.slice(1);

      const transactions: ImportableTransaction[] = [];
      const errors: ImportError[] = [];

      rows.forEach((row, idx) => {
        const rowIndex = idx + 2; // account for header row
        try {
          const rowObject: Record<string, any> = {};
          headers.forEach((h, i) => {
            rowObject[h] = (row as any[])[i];
          });
          const tx = this.mapRowToTransaction(rowObject, mapping, rowIndex);
          if (tx) transactions.push(tx);
        } catch (error) {
          errors.push({
            row: rowIndex,
            field: "general",
            message:
              error instanceof Error ? error.message : "Unknown parsing error",
            data: row as any,
          });
        }
      });

      return {
        totalRows: rows.length,
        validTransactions: transactions.length,
        errors,
        preview: transactions,
        duplicates: [],
      };
    } catch (error) {
      throw new Error(
        `Excel parsing failed: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Map a row of data to a transaction using the provided column mapping
   */
  private static mapRowToTransaction(
    row: any,
    mapping: ColumnMapping,
    rowIndex: number
  ): ImportableTransaction | null {
    // Date
    const dateValue = row[mapping.date];
    if (!dateValue) throw new Error(`Date is required (row ${rowIndex})`);
    const parsedDate = this.parseDate(dateValue);
    if (!parsedDate)
      throw new Error(`Invalid date format: "${dateValue}" (row ${rowIndex})`);

    // Description
    const description = row[mapping.description];
    if (
      !description ||
      typeof description !== "string" ||
      description.trim() === ""
    ) {
      throw new Error(`Description is required (row ${rowIndex})`);
    }

    // Amount
    const amountValue = row[mapping.amount];
    if (
      amountValue === undefined ||
      amountValue === null ||
      amountValue === ""
    ) {
      throw new Error(`Amount is required (row ${rowIndex})`);
    }
    const parsedAmt = this.parseAmount(amountValue);
    if (isNaN(parsedAmt))
      throw new Error(`Invalid amount: "${amountValue}" (row ${rowIndex})`);

    // Type inference: we store amounts positive; sign derived from type
    let type: "expense" | "income";
    if (this.isDiscoverMapping(mapping)) {
      // Discover CSV often uses positive = charge, negative = credit/payment
      type = parsedAmt > 0 ? "expense" : "income";
    } else if (mapping.type && row[mapping.type]) {
      const t = String(row[mapping.type]).toLowerCase();
      if (/(income|deposit|credit|refund|payment)/.test(t)) type = "income";
      else if (/(expense|debit|withdrawal|purchase|charge)/.test(t)) type = "expense";
      else type = parsedAmt < 0 ? "income" : "expense";
    } else {
      type = parsedAmt < 0 ? "income" : "expense";
    }

    const category =
      mapping.category && row[mapping.category]
        ? this.categorizeTransaction(String(row[mapping.category]).trim())
        : this.categorizeTransaction(String(description));

    const note =
      mapping.note && row[mapping.note]
        ? String(row[mapping.note]).trim()
        : undefined;

    return {
      date: parsedDate, // stays yyyy-mm-dd
      description: String(description).trim(),
      amount: Math.abs(parsedAmt), // store positive
      type, // ✅ now correct
      category,
      note,
    };
  }

  private static isDiscoverMapping(mapping: ColumnMapping): boolean {
    const d = (mapping.date || "").toLowerCase();
    const desc = (mapping.description || "").toLowerCase();
    const amt = (mapping.amount || "").toLowerCase();
    // Heuristic: classic Discover export headers
    return d.includes("trans. date") && desc === "description" && amt === "amount";
  }

  /**
   * Date parsing with Excel serial and common formats; returns yyyy-mm-dd
   */
  // services/importService.ts
  private static parseDate(dateValue: any): string | null {
    if (dateValue == null) return null;

    // Excel serial
    if (typeof dateValue === "number") {
      const d = XLSX.SSF.parse_date_code(dateValue);
      if (!d) return null;
      return new Date(Date.UTC(d.y, d.m - 1, d.d)).toISOString().slice(0, 10);
    }

    const s = String(dateValue).trim();

    // YYYY-MM-DD
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;

    // MM/DD/YYYY
    let m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) {
      const [, mo, da, yr] = m;
      return `${yr}-${mo.padStart(2, "0")}-${da.padStart(2, "0")}`;
    }

    // MM-DD-YYYY
    m = s.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
    if (m) {
      const [, mo, da, yr] = m;
      return `${yr}-${mo.padStart(2, "0")}-${da.padStart(2, "0")}`;
    }

    // Pull date from strings like "2025-08-26 00:00:00"
    m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})\b/);
    if (m) {
      const [, yr, mo, da] = m;
      return `${yr}-${mo.padStart(2, "0")}-${da.padStart(2, "0")}`;
    }

    return null; // fail loudly → row error instead of silently becoming “today”
  }

  /**
   * Amount parsing supporting $, commas, spaces, parentheses and negatives
   */
  private static parseAmount(amountValue: any): number {
    if (typeof amountValue === "number") return amountValue;

    if (typeof amountValue !== "string") return NaN;

    // Detect negativity before stripping
    const neg = /[(−-]/.test(amountValue); // includes unicode minus

    // Clean
    let clean = amountValue
      .replace(/[,$\s]/g, "")
      .replace(/[()]/g, "")
      .trim();

    // keep only digits, dot, dash
    clean = clean.replace(/[^\d.-]/g, "");

    const n = parseFloat(clean);
    if (isNaN(n)) return NaN;
    return neg && n > 0 ? -n : n;
  }

  /**
   * Naive categorizer
   */
  private static categorizeTransaction(description: string): string {
    const desc = description.toLowerCase();
    if (
      /(restaurant|cafe|starbucks|mcdonald|food|dining|grocery|supermarket|walmart)/.test(
        desc
      )
    )
      return "Food";
    if (/(gas|fuel|uber|lyft|taxi|parking|metro|bus|train)/.test(desc))
      return "Transportation";
    if (/(amazon|target|mall|store|retail|purchase)/.test(desc))
      return "Shopping";
    if (
      /(electric|water|internet|phone|utility|bill|payment|service)/.test(desc)
    )
      return "Bills";
    if (/(movie|theater|netflix|spotify|game|entertainment)/.test(desc))
      return "Entertainment";
    if (/(pharmacy|hospital|doctor|medical|health|cvs)/.test(desc))
      return "Health";
    return "Other";
  }

  /**
   * Convert ImportableTransaction to TransactionDoc for DB
   * (Consider adding a dedupeHash field to TransactionDoc)
   */
  // services/importService.ts
  // services/importService.ts
  static convertToTransactionDoc(
    transaction: ImportableTransaction,
    userId: ObjectId,
    dedupeHash?: string
  ): Omit<TransactionDoc, "_id"> {
    const now = new Date();

    // transaction.date MUST be YYYY-MM-DD here
    const m = transaction.date.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) throw new Error(`Bad normalized date: ${transaction.date}`);
    const [, y, mo, d] = m;
    // use noon UTC to avoid any DST edge cases
    const dateUtc = new Date(
      Date.UTC(Number(y), Number(mo) - 1, Number(d), 12, 0, 0)
    );

    const amountCents = Math.round(transaction.amount * 100);
    return {
      userId,
      type: transaction.type || "expense",
      amountCents,
      amount: amountCents / 100, // mirror for backward compatibility
      category: transaction.category || transaction.categorySuggested || "Other",
      note: transaction.merchantCanonical || transaction.note || transaction.description,
      tags: Array.isArray(transaction.tags) ? transaction.tags.slice(0, 10) : undefined,
      merchantCanonical: transaction.merchantCanonical,
      categorySuggested: transaction.categorySuggested,
      categoryConfidence: transaction.categoryConfidence,
      date: dateUtc, // ← the real transaction day
      createdAt: now, // import timestamp (today)
      updatedAt: now,
      ...(dedupeHash ? { dedupeHash } : {}),
    } as any;
  }

  /**
   * Duplicate detection (lightweight)
   */
  static detectDuplicates(
    newTransactions: ImportableTransaction[],
    existingTransactions: TransactionDoc[]
  ): ImportableTransaction[] {
    const duplicates: ImportableTransaction[] = [];
    newTransactions.forEach((newTx) => {
      const isDuplicate = existingTransactions.some(
        (existing) =>
          // Same date (to ISO yyyy-mm-dd)
          existing.date.toISOString().slice(0, 10) === newTx.date &&
          // Same amount (both positive in this schema)
          Math.abs(existing.amount - newTx.amount) < 0.01 &&
          // Similar description
          this.similarStrings(existing.note || "", newTx.description)
      );
      if (isDuplicate) duplicates.push(newTx);
    });
    return duplicates;
  }

  private static similarStrings(
    str1: string,
    str2: string,
    threshold = 0.8
  ): boolean {
    const a = str1.toLowerCase().trim();
    const b = str2.toLowerCase().trim();
    if (a === b) return true;
    const wordsA = new Set(a.split(/\s+/));
    const wordsB = new Set(b.split(/\s+/));
    const inter = new Set([...wordsA].filter((x) => wordsB.has(x)));
    const union = new Set([...wordsA, ...wordsB]);
    return union.size ? inter.size / union.size >= threshold : false;
  }

  /**
   * Optional: stable dedupe hash (add unique index on { userId, dedupeHash })
   */
  static makeDedupeHash(tx: {
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
}

/** ---- helpers ---- **/

function sniffCSV(buf: Buffer): { delimiter: string } {
  // Look at the first line for delimiter frequency
  const head = buf.slice(0, Math.min(buf.length, 4096)).toString("utf8");
  const firstLine = head.split(/\r?\n/)[0] ?? "";
  const counts = {
    ",": (firstLine.match(/,/g) || []).length,
    ";": (firstLine.match(/;/g) || []).length,
    "\t": (firstLine.match(/\t/g) || []).length,
  };
  const delimiter = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  return { delimiter };
}
