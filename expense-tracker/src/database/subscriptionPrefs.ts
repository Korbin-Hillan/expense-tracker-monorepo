import { Db, ObjectId, Collection } from 'mongodb';
import { getDb } from './databaseConnection.js';

export type SubscriptionPrefDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  noteNorm: string; // lowercased, trimmed note
  ignored?: boolean;
  cancelled?: boolean;
  createdAt: Date;
  updatedAt: Date;
};

export async function subscriptionPrefsCollection(): Promise<Collection<SubscriptionPrefDoc>> {
  const db: Db = await getDb();
  return db.collection<SubscriptionPrefDoc>('subscription_prefs');
}

export async function ensureSubscriptionPrefsIndexes() {
  const col = await subscriptionPrefsCollection();
  try {
    await col.createIndex({ userId: 1, noteNorm: 1 }, { name: 'user_note', unique: true });
  } catch (e) {
    if (!(e as any).message?.includes('already exists')) throw e;
  }
}

