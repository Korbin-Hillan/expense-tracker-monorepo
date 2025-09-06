import { Db, ObjectId, Collection } from 'mongodb';
import { getDb } from './databaseConnection.js';

export type AlertPrefDoc = {
  _id?: ObjectId;
  userId: ObjectId;
  key: string; // e.g., budget:Food, subscription:netflix
  muted: boolean;
  createdAt: Date;
  updatedAt: Date;
};

export async function alertPrefsCollection(): Promise<Collection<AlertPrefDoc>> {
  const db: Db = await getDb();
  return db.collection<AlertPrefDoc>('alert_prefs');
}

export async function ensureAlertPrefsIndexes() {
  const col = await alertPrefsCollection();
  try {
    await col.createIndex({ userId: 1, key: 1 }, { name: 'user_key', unique: true });
  } catch (e) {
    if (!(e as any).message?.includes('already exists')) throw e;
  }
}

