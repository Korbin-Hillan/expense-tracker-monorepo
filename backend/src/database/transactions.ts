// database/transactions.ts
import { getDb } from "./databaseConnection.js";
import { ObjectId, Db, Collection } from "mongodb";

export type TransactionDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  type: "expense" | "income";
  // Monetary amount stored as integer cents to avoid FP drift
  amountCents: number;
  // Optional float for backward compatibility (derived)
  amount?: number;
  category: string;
  note?: string;
  tags?: string[];
  receiptUrl?: string | null;
  date: Date;
  createdAt: Date;
  updatedAt: Date;
  // add this so TS knows the field exists
  dedupeHash?: string;
  // AI-enrichment (optional)
  categorySuggested?: string;
  categoryConfidence?: number;
  merchantCanonical?: string;
  anomalyScore?: number;
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
  try {
    await col.createIndex({ userId: 1, categorySuggested: 1 }, { name: "user_categorySuggested" });
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
  try {
    await col.createIndex({ userId: 1, type: 1 }, { name: "user_type" });
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
  try {
    await col.createIndex({ userId: 1, category: 1 }, { name: "user_category" });
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
  try {
    await col.createIndex({ userId: 1, tags: 1 }, { name: "user_tags" });
  } catch (e) {
    if (!(e as any).message?.includes("already exists")) throw e;
  }
}
