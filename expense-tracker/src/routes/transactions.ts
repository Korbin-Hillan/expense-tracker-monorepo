import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";
import { ExportService } from "../services/exportService.ts";
import { readFileSync, unlinkSync } from "fs";
import { toISOStringNoMillis } from "../utils/dates.ts";
import { rulesCollection } from "../database/rules.ts";
export const transactionsRouter = Router();

transactionsRouter.post(
  "/api/transactions",
  requireAppJWT,
  async (req, res) => {
    const userId = (req as any).userId as string;
    const { type, amount, category, note, date, tags } = req.body ?? {};

    if (!["expense", "income"].includes(type)) {
      res.status(400).json({ error: "bad_type" });
      return;
    }
    if (typeof amount !== "number") {
      res.status(400).json({ error: "bad_amount" });
      return;
    }
    if (!category || typeof category !== "string") {
      res.status(400).json({ error: "bad_category" });
      return;
    }

    const txDate = date ? new Date(date) : new Date();
    if (isNaN(txDate.getTime())) {
      res.status(400).json({ error: "bad_date" });
      return;
    }

    const col = await transactionsCollection(); // ✅ await
    const now = new Date();
    const cents = Math.round(amount * 100);
    const doc: any = {
      userId: new ObjectId(userId),
      type,
      amountCents: cents,
      amount: cents / 100, // mirror for backward compatibility
      category,
      note: typeof note === "string" && note.trim() ? note.trim() : undefined,
      tags: Array.isArray(tags) ? tags.filter((t: any) => typeof t === 'string' && t.trim()).slice(0, 20) : undefined,
      date: txDate,
      createdAt: now,
      updatedAt: now,
    };

    // Apply rules on create
    try {
      const rcol = await rulesCollection()
      const rules = await rcol.find({ userId: new ObjectId(userId), enabled: true }).sort({ order: 1, createdAt: 1 }).toArray()
      for (const r of rules) {
        const fieldVal = String((doc as any)[r.when.field] || '')
        let match = false
        if (r.when.type === 'contains') match = fieldVal.toLowerCase().includes(r.when.value.toLowerCase())
        else if (r.when.type === 'regex') { try { match = new RegExp(r.when.value, 'i').test(fieldVal) } catch { match = false } }
        if (match) {
          if (r.set.category) doc.category = r.set.category
          if (Array.isArray(r.set.tags) && r.set.tags.length) {
            const cur = Array.isArray(doc.tags) ? doc.tags : []
            doc.tags = Array.from(new Set([...cur, ...r.set.tags])).slice(0, 20)
          }
          break
        }
      }
    } catch {}

    const result = await col.insertOne(doc);
    res.status(201).json({
      id: result.insertedId.toHexString(),
      type: doc.type,
      amount: doc.amountCents / 100,
      category: doc.category,
      note: doc.note ?? null,
      tags: Array.isArray(doc.tags) ? doc.tags : [],
      date: toISOStringNoMillis(doc.date),
    });
  }
);

// Receipt upload/delete
import multer from 'multer'
import fs from 'fs'
import path from 'path'
const receiptUpload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } })

transactionsRouter.post('/api/transactions/:id/receipt', requireAppJWT as any, receiptUpload.single('file'), async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const id = String(req.params.id)
    if (!ObjectId.isValid(id)) { res.status(400).json({ error: 'invalid_transaction_id' }); return }
    if (!req.file) { res.status(400).json({ error: 'no_file' }); return }
    const mt = String(req.file.mimetype || '').toLowerCase()
    const ext = mt.includes('png') ? 'png' : mt.includes('jpeg') || mt.includes('jpg') ? 'jpg' : mt.includes('webp') ? 'webp' : mt.includes('pdf') ? 'pdf' : null
    if (!ext) { res.status(400).json({ error: 'unsupported_type' }); return }
    const col = await transactionsCollection()
    const tx = await col.findOne({ _id: new ObjectId(id), userId })
    if (!tx) { res.status(404).json({ error: 'transaction_not_found' }); return }
    const root = path.resolve(process.cwd(), 'uploads')
    const dir = path.join(root, 'receipts', String(userId))
    try { fs.mkdirSync(dir, { recursive: true }) } catch {}
    const filename = `${id}-${Date.now()}.${ext}`
    fs.writeFileSync(path.join(dir, filename), req.file.buffer)
    const url = `/uploads/receipts/${userId}/${filename}`
    await col.updateOne({ _id: new ObjectId(id) }, { $set: { receiptUrl: url, updatedAt: new Date() } })
    res.json({ success: true, receiptUrl: url })
  } catch (e) {
    res.status(500).json({ error: 'receipt_upload_failed' })
  }
})

transactionsRouter.delete('/api/transactions/:id/receipt', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const id = String(req.params.id)
    if (!ObjectId.isValid(id)) { res.status(400).json({ error: 'invalid_transaction_id' }); return }
    const col = await transactionsCollection()
    const tx = await col.findOne({ _id: new ObjectId(id), userId })
    if (!tx) { res.status(404).json({ error: 'transaction_not_found' }); return }
    await col.updateOne({ _id: new ObjectId(id) }, { $unset: { receiptUrl: '' }, $set: { updatedAt: new Date() } })
    res.json({ success: true })
  } catch (e) {
    res.status(500).json({ error: 'receipt_delete_failed' })
  }
})

transactionsRouter.get("/api/transactions", requireAppJWT, async (req, res) => {
  const userId = (req as any).userId as string;
  const rawLimit = parseInt(String(req.query.limit ?? ""), 10);
  const limit = Math.min(isNaN(rawLimit) || rawLimit <= 0 ? 20 : rawLimit, 100);
  const rawSkip = parseInt(String(req.query.skip ?? ""), 10);
  const skip = isNaN(rawSkip) || rawSkip < 0 ? 0 : rawSkip;

  const col = await transactionsCollection(); // ✅ await
  const docs = await col
    .find({ userId: new ObjectId(userId) })
    .sort({ date: -1, _id: -1 })
    .skip(skip)
    .limit(limit)
    .toArray();

  res.json(
    docs.map((d) => ({
      id: d._id!.toHexString(),
      type: d.type,
      amount: (d as any).amountCents ? (d as any).amountCents / 100 : (d as any).amount,
      category: d.category,
      note: d.note ?? null,
      tags: Array.isArray((d as any).tags) ? (d as any).tags : [],
      receiptUrl: (d as any).receiptUrl || null,
      date: toISOStringNoMillis(d.date),
    }))
  );
});

// PUT /api/transactions/:id - Update a transaction
transactionsRouter.put(
  "/api/transactions/:id",
  requireAppJWT,
  async (req, res) => {
    const userId = (req as any).userId as string;
    const transactionId = req.params.id;

    if (!ObjectId.isValid(transactionId)) {
      res.status(400).json({ error: "invalid_transaction_id" });
      return;
    }

    const { type, amount, category, note, date, tags } = req.body ?? {};

    if (!["expense", "income"].includes(type)) {
      res.status(400).json({ error: "bad_type" });
      return;
    }
    if (typeof amount !== "number") {
      res.status(400).json({ error: "bad_amount" });
      return;
    }
    if (!category || typeof category !== "string") {
      res.status(400).json({ error: "bad_category" });
      return;
    }

    let txDate: Date | undefined;
    if (date !== undefined) {
      txDate = new Date(date);
      if (isNaN(txDate.getTime())) {
        res.status(400).json({ error: "bad_date" });
        return;
      }
    }

    const col = await transactionsCollection();
    const existing = await col.findOne({
      _id: new ObjectId(transactionId),
      userId: new ObjectId(userId),
    });
    if (!existing) {
      res.status(404).json({ error: "transaction_not_found" });
      return;
    }

    const updateDoc: any = {
      type,
      amountCents: Math.round(amount * 100),
      amount: amount, // keep float for back-compat
      category,
      note: typeof note === "string" && note.trim() ? note.trim() : undefined,
      updatedAt: new Date(),
    };
    if (Array.isArray(tags)) {
      updateDoc.tags = tags.filter((t: any) => typeof t === 'string' && t.trim()).slice(0, 20)
    }
    if (txDate) {
      updateDoc.date = txDate;
    }
    await col.updateOne(
      { _id: existing._id, userId: existing.userId },
      { $set: updateDoc }
    );

    res.json({
      id: transactionId,
      type: updateDoc.type,
      amount: updateDoc.amountCents / 100,
      category: updateDoc.category,
      note: updateDoc.note ?? existing.note ?? null,
      date: toISOStringNoMillis(txDate ?? existing.date),
    });
  }
);

// DELETE /api/transactions/clear - Clear all transactions for the user
transactionsRouter.delete(
  "/api/transactions/clear",
  requireAppJWT,
  async (req, res) => {
    console.log("🧹 DELETE /clear request received");
    const userId = (req as any).userId as string;

    console.log("👤 User ID attempting to clear all transactions:", userId);

    const col = await transactionsCollection();
    console.log("🔍 Attempting to delete all transactions for user:", userId);

    const result = await col.deleteMany({
      userId: new ObjectId(userId), // Ensure user can only delete their own transactions
    });

    console.log("📊 Clear all operation result:", {
      deletedCount: result.deletedCount,
      acknowledged: result.acknowledged,
    });

    console.log(`✅ Successfully cleared ${result.deletedCount} transactions`);
    res.json({
      success: true,
      deletedCount: result.deletedCount,
    });
  }
);

// DELETE /api/transactions/:id - Delete a transaction
transactionsRouter.delete(
  "/api/transactions/:id",
  requireAppJWT,
  async (req, res) => {
    console.log("🗑️ DELETE request received for transaction:", req.params.id);
    const userId = (req as any).userId as string;
    const transactionId = req.params.id;

    console.log("👤 User ID attempting delete:", userId);
    console.log("🎯 Transaction ID to delete:", transactionId);

    if (!ObjectId.isValid(transactionId)) {
      console.log("❌ Invalid transaction ID format:", transactionId);
      res.status(400).json({ error: "invalid_transaction_id" });
      return;
    }

    const col = await transactionsCollection();
    console.log("🔍 Attempting to delete transaction with query:", {
      _id: new ObjectId(transactionId),
      userId: new ObjectId(userId),
    });

    const result = await col.deleteOne({
      _id: new ObjectId(transactionId),
      userId: new ObjectId(userId), // Ensure user can only delete their own transactions
    });

    console.log("📊 Delete operation result:", {
      deletedCount: result.deletedCount,
      acknowledged: result.acknowledged,
    });

    if (result.deletedCount === 0) {
      console.log(
        "❌ Transaction not found or user doesn't have permission to delete it"
      );
      res.status(404).json({ error: "transaction_not_found" });
      return;
    }

    console.log("✅ Transaction deleted successfully");
    res.json({ success: true });
  }
);

// GET /api/transactions/export/csv - Export transactions as CSV
transactionsRouter.get(
  "/api/transactions/export/csv",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      const { startDate, endDate, category, type } = req.query;

      // Build filter query
      const filter: any = { userId: new ObjectId(userId) };

      if (startDate || endDate) {
        filter.date = {};
        if (startDate) filter.date.$gte = new Date(startDate as string);
        if (endDate) filter.date.$lte = new Date(endDate as string);
      }

      if (category && category !== "all") {
        filter.category = category as string;
      }

      if (type && type !== "all") {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions =
        ExportService.prepareTransactionsForExport(transactions);
      const csvPath = await ExportService.generateCSV(exportableTransactions);

      // Read file and send as response
      const csvContent = readFileSync(csvPath);

      res.setHeader("Content-Type", "text/csv");
      res.setHeader(
        "Content-Disposition",
        "attachment; filename=transactions.csv"
      );
      res.send(csvContent);

      // Clean up temp file
      unlinkSync(csvPath);
    } catch (error) {
      console.error("CSV export error:", error);
      res.status(500).json({ error: "export_failed" });
    }
  }
);

// GET /api/transactions/export/excel - Export transactions as Excel
transactionsRouter.get(
  "/api/transactions/export/excel",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      const { startDate, endDate, category, type } = req.query;

      // Build filter query
      const filter: any = { userId: new ObjectId(userId) };

      if (startDate || endDate) {
        filter.date = {};
        if (startDate) filter.date.$gte = new Date(startDate as string);
        if (endDate) filter.date.$lte = new Date(endDate as string);
      }

      if (category && category !== "all") {
        filter.category = category as string;
      }

      if (type && type !== "all") {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions =
        ExportService.prepareTransactionsForExport(transactions);
      const excelPath = ExportService.generateExcel(exportableTransactions);

      // Read file and send as response
      const excelContent = readFileSync(excelPath);

      res.setHeader(
        "Content-Type",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      );
      res.setHeader(
        "Content-Disposition",
        "attachment; filename=transactions.xlsx"
      );
      res.send(excelContent);

      // Clean up temp file
      unlinkSync(excelPath);
    } catch (error) {
      console.error("Excel export error:", error);
      res.status(500).json({ error: "export_failed" });
    }
  }
);

// GET /api/transactions/summary - Get transaction summary statistics
transactionsRouter.get(
  "/api/transactions/summary",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      const { startDate, endDate, category, type } = req.query;

      // Build filter query
      const filter: any = { userId: new ObjectId(userId) };

      if (startDate || endDate) {
        filter.date = {};
        if (startDate) filter.date.$gte = new Date(startDate as string);
        if (endDate) filter.date.$lte = new Date(endDate as string);
      }

      if (category && category !== "all") {
        filter.category = category as string;
      }

      if (type && type !== "all") {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions =
        ExportService.prepareTransactionsForExport(transactions);
      const summary = ExportService.generateSummaryStats(
        exportableTransactions
      );

      res.json(summary);
    } catch (error) {
      console.error("Summary generation error:", error);
      res.status(500).json({ error: "summary_failed" });
    }
  }
);

// Duplicates: list probable duplicates (same date, amount, similar note)
transactionsRouter.get('/api/transactions/duplicates', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const col = await transactionsCollection()
    const docs = await col.find({ userId }).project({ date: 1, amountCents: 1, amount: 1, note: 1 }).toArray()
    const groups = new Map<string, any[]>();
    function norm(s: string) { return String(s || '').toLowerCase().replace(/\s+/g, ' ').trim() }
    for (const d of docs) {
      const amt = (d as any).amountCents ? (d as any).amountCents / 100 : (d as any).amount
      const key = `${d.date.toISOString().slice(0,10)}|${amt.toFixed(2)}|${norm(d.note || '')}`
      const arr = groups.get(key) || []
      arr.push({ id: d._id!.toHexString(), date: d.date.toISOString(), amount: amt, note: d.note || '' })
      groups.set(key, arr)
    }
    const dupes = Array.from(groups.entries()).filter(([, arr]) => arr.length > 1).map(([key, arr]) => ({ key, items: arr }))
    res.json({ groups: dupes })
  } catch (e) {
    res.status(500).json({ error: 'list_duplicates_failed' })
  }
})

transactionsRouter.post('/api/transactions/duplicates/resolve', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const keepId = String(req.body?.keepId || '')
    const deleteIds: string[] = Array.isArray(req.body?.deleteIds) ? req.body.deleteIds : []
    if (!ObjectId.isValid(keepId)) { res.status(400).json({ error: 'bad_keep_id' }); return }
    const ids = deleteIds.filter(id => ObjectId.isValid(id) && id !== keepId).map(id => new ObjectId(id))
    if (!ids.length) { res.json({ deleted: 0 }); return }
    const col = await transactionsCollection()
    const result = await col.deleteMany({ _id: { $in: ids }, userId })
    res.json({ deleted: result.deletedCount || 0 })
  } catch (e) {
    res.status(500).json({ error: 'resolve_duplicates_failed' })
  }
})
