import { Db, ObjectId, Collection } from 'mongodb';
import { getDb } from './databaseConnection.js';

export type BudgetDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  // category "Overall" can represent total monthly budget
  category: string; // e.g., "Food", "Transportation" or "Overall"
  monthlyCents: number; // integer cents
  createdAt: Date;
  updatedAt: Date;
};

export async function budgetsCollection(): Promise<Collection<BudgetDoc>> {
  const db: Db = await getDb();
  return db.collection<BudgetDoc>('budgets');
}

export async function ensureBudgetIndexes() {
  const col = await budgetsCollection();
  try {
    await col.createIndex({ userId: 1, category: 1 }, { name: 'user_category', unique: true });
  } catch (e) {
    if (!(e as any).message?.includes('already exists')) throw e;
  }
}

