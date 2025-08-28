// database/transactions.ts
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
  // add this so TS knows the field exists
  dedupeHash?: string;
};

// ✅ make this async
export async function transactionsCollection(): Promise<
  Collection<TransactionDoc>
> {
  const db: Db = await getDb();
  return db.collection<TransactionDoc>("transactions");
}

export async function ensureTransactionIndexes() {
  const col = await transactionsCollection();
  try {
    await col.createIndex({ userId: 1, date: -1 }, { name: "user_date_desc" });
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
  try {
    await col.createIndex(
      { userId: 1, dedupeHash: 1 },
      {
        name: "user_dedupeHash_unique",
        unique: true,
        partialFilterExpression: { dedupeHash: { $exists: true } },
      }
    );
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
}
