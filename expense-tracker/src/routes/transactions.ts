import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";

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
  const limit = Math.min(
    parseInt(String(req.query.limit ?? "20"), 10) || 20,
    100
  );
  const skip = parseInt(String(req.query.skip ?? "0"), 10) || 0;

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

    const txDate = date ? new Date(date) : new Date();
    if (isNaN(txDate.getTime())) {
      res.status(400).json({ error: "bad_date" });
      return;
    }

    const col = await transactionsCollection();
    const updateDoc = {
      type,
      amount,
      category,
      note: typeof note === "string" && note.trim() ? note.trim() : undefined,
      date: txDate,
      updatedAt: new Date(),
    };

    const result = await col.updateOne(
      { 
        _id: new ObjectId(transactionId),
        userId: new ObjectId(userId) // Ensure user can only update their own transactions
      },
      { $set: updateDoc }
    );

    if (result.matchedCount === 0) {
      res.status(404).json({ error: "transaction_not_found" });
      return;
    }

    res.json({
      id: transactionId,
      type: updateDoc.type,
      amount: updateDoc.amount,
      category: updateDoc.category,
      note: updateDoc.note ?? null,
      date: updateDoc.date.toISOString(),
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
      userId: new ObjectId(userId)
    });
    
    const result = await col.deleteOne({
      _id: new ObjectId(transactionId),
      userId: new ObjectId(userId) // Ensure user can only delete their own transactions
    });

    console.log("📊 Delete operation result:", {
      deletedCount: result.deletedCount,
      acknowledged: result.acknowledged
    });

    if (result.deletedCount === 0) {
      console.log("❌ Transaction not found or user doesn't have permission to delete it");
      res.status(404).json({ error: "transaction_not_found" });
      return;
    }

    console.log("✅ Transaction deleted successfully");
    res.json({ success: true });
  }
);
