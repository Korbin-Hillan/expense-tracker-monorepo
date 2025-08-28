import { getDb } from "./databaseConnection.js";
import { ObjectId, Db, Collection } from "mongodb";

export type RecurringExpenseDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  name: string;
  category: string;
  averageAmount: number;
  frequency: "monthly" | "weekly" | "biweekly" | "yearly" | "daily";
  firstDetected: Date;
  lastSeen: Date;
  occurrenceCount: number;
  isActive: boolean;
  patterns: {
    descriptions: string[];
    amountRange: { min: number; max: number };
    dayOfMonth?: number; // for monthly bills
    dayOfWeek?: number; // for weekly bills
  };
  createdAt: Date;
  updatedAt: Date;
};

export async function recurringExpensesCollection(): Promise<
  Collection<RecurringExpenseDoc>
> {
  const db: Db = await getDb();
  return db.collection<RecurringExpenseDoc>("recurringExpenses");
}

export async function ensureRecurringExpenseIndexes() {
  const col = await recurringExpensesCollection();
  await col.createIndex({ userId: 1, name: 1 }, { name: "user_name", unique: true });
  await col.createIndex({ userId: 1, isActive: 1 }, { name: "user_active" });
}