import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";
import { ExportService } from "../services/exportService.ts";
import { readFileSync, unlinkSync } from "fs";

export const transactionsRouter = Router();

transactionsRouter.post(
  "/api/transactions",
  requireAppJWT,
  async (req, res) => {
    const userId = (req as any).userId as string;
    const { type, amount, category, note, date } = req.body ?? {};

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
    const doc = {
      userId: new ObjectId(userId),
      type,
      amount,
      category,
      note: typeof note === "string" && note.trim() ? note.trim() : undefined,
      date: txDate,
      createdAt: now,
      updatedAt: now,
    };

    const result = await col.insertOne(doc);
    res.status(201).json({
      id: result.insertedId.toHexString(),
      type: doc.type,
      amount: doc.amount,
      category: doc.category,
      note: doc.note ?? null,
      date: doc.date.toISOString(),
    });
  }
);

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
      amount: d.amount,
      category: d.category,
      note: d.note ?? null,
      date: d.date.toISOString(),
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

    const { type, amount, category, note, date } = req.body ?? {};

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
      amount,
      category,
      note: typeof note === "string" && note.trim() ? note.trim() : undefined,
      updatedAt: new Date(),
    };
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
      amount: updateDoc.amount,
      category: updateDoc.category,
      note: updateDoc.note ?? existing.note ?? null,
      date: (txDate ?? existing.date).toISOString(),
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
      deletedCount: result.deletedCount 
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
      
      if (category && category !== 'all') {
        filter.category = category as string;
      }
      
      if (type && type !== 'all') {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions = ExportService.prepareTransactionsForExport(transactions);
      const csvPath = await ExportService.generateCSV(exportableTransactions);

      // Read file and send as response
      const csvContent = readFileSync(csvPath);
      
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=transactions.csv');
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
      
      if (category && category !== 'all') {
        filter.category = category as string;
      }
      
      if (type && type !== 'all') {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions = ExportService.prepareTransactionsForExport(transactions);
      const excelPath = ExportService.generateExcel(exportableTransactions);

      // Read file and send as response
      const excelContent = readFileSync(excelPath);
      
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename=transactions.xlsx');
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
      
      if (category && category !== 'all') {
        filter.category = category as string;
      }
      
      if (type && type !== 'all') {
        filter.type = type as string;
      }

      const col = await transactionsCollection();
      const transactions = await col
        .find(filter)
        .sort({ date: -1, _id: -1 })
        .toArray();

      const exportableTransactions = ExportService.prepareTransactionsForExport(transactions);
      const summary = ExportService.generateSummaryStats(exportableTransactions);

      res.json(summary);
    } catch (error) {
      console.error("Summary generation error:", error);
      res.status(500).json({ error: "summary_failed" });
    }
  }
);
