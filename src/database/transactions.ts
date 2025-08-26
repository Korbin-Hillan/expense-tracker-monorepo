import { getDb } from "./databaseConnection.js";
import { ObjectId, Db, Collection } from "mongodb";

export type TransactionDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  type: "expense" | "income";
  amount: number;
  category: string;
  note?: string;
  date: Date;
  createdAt: Date;
  updatedAt: Date;
};

// ✅ make this async
export async function transactionsCollection(): Promise<
  Collection<TransactionDoc>
> {
  const db: Db = await getDb();
  return db.collection<TransactionDoc>("transactions");
}

// ensure helpful indexes once on startup
export async function ensureTransactionIndexes() {
  const col = await transactionsCollection(); // ✅ await the collection
  await col.createIndex({ userId: 1, date: -1 }, { name: "user_date_desc" });
}
