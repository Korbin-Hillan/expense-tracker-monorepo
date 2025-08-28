import { getDb } from "./databaseConnection.js";
import { ObjectId, Db, Collection } from "mongodb";

export type ExpenseDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  amount: number;
  category: string;
  description: string;
  date: Date;
  recurringExpenseId?: ObjectId; // Link to recurring expense if detected
  isRecurring: boolean;
  tags?: string[];
  createdAt: Date;
  updatedAt: Date;
  importSource?: string; // 'csv', 'manual', etc.
};

export async function expensesCollection(): Promise<Collection<ExpenseDoc>> {
  const db: Db = await getDb();
  return db.collection<ExpenseDoc>("expenses");
}

export async function ensureExpenseIndexes() {
  const col = await expensesCollection();
  await col.createIndex({ userId: 1, date: -1 }, { name: "user_date_desc" });
  await col.createIndex({ userId: 1, category: 1 }, { name: "user_category" });
  await col.createIndex({ userId: 1, recurringExpenseId: 1 }, { name: "user_recurring" });
}