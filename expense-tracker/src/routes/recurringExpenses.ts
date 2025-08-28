import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.js";
import { recurringExpensesCollection } from "../database/recurringExpenses.js";
import { expensesCollection } from "../database/expenses.js";

export const recurringExpensesRouter = Router();

// Get all recurring expenses for a user
recurringExpensesRouter.get(
  "/api/recurring-expenses",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      if (!ObjectId.isValid(userId)) {
        return res.status(400).json({ error: "Invalid user id" });
      }

      const col = await recurringExpensesCollection();
      const recurringExpenses = await col
        .find({ userId: new ObjectId(userId), isActive: true })
        .sort({ lastSeen: -1 })
        .toArray();

      return res.json({ recurringExpenses });
    } catch (err) {
      console.error("Get recurring expenses error:", err);
      return res.status(500).json({ error: "Failed to get recurring expenses" });
    }
  }
);

// Get expenses for a specific recurring expense
recurringExpensesRouter.get(
  "/api/recurring-expenses/:id/expenses",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      const recurringExpenseId = req.params.id;

      if (!ObjectId.isValid(userId) || !ObjectId.isValid(recurringExpenseId)) {
        return res.status(400).json({ error: "Invalid id" });
      }

      const expCol = await expensesCollection();
      const expenses = await expCol
        .find({
          userId: new ObjectId(userId),
          recurringExpenseId: new ObjectId(recurringExpenseId)
        })
        .sort({ date: -1 })
        .toArray();

      return res.json({ expenses });
    } catch (err) {
      console.error("Get recurring expense details error:", err);
      return res.status(500).json({ error: "Failed to get recurring expense details" });
    }
  }
);

// Toggle recurring expense active status
recurringExpensesRouter.patch(
  "/api/recurring-expenses/:id/toggle",
  requireAppJWT,
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      const recurringExpenseId = req.params.id;

      if (!ObjectId.isValid(userId) || !ObjectId.isValid(recurringExpenseId)) {
        return res.status(400).json({ error: "Invalid id" });
      }

      const col = await recurringExpensesCollection();
      const recurringExpense = await col.findOne({
        _id: new ObjectId(recurringExpenseId),
        userId: new ObjectId(userId)
      });

      if (!recurringExpense) {
        return res.status(404).json({ error: "Recurring expense not found" });
      }

      await col.updateOne(
        { _id: new ObjectId(recurringExpenseId) },
        {
          $set: {
            isActive: !recurringExpense.isActive,
            updatedAt: new Date()
          }
        }
      );

      return res.json({ success: true, isActive: !recurringExpense.isActive });
    } catch (err) {
      console.error("Toggle recurring expense error:", err);
      return res.status(500).json({ error: "Failed to toggle recurring expense" });
    }
  }
);