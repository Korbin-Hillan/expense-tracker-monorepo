import { getDb } from './databaseConnection.js'
import { ObjectId, Db, Collection } from 'mongodb'

export type ImportPresetDoc = {
  _id?: ObjectId
  userId: ObjectId
  name: string
  signature: string // hash of column headers etc.
  mapping: {
    date?: string; description?: string; amount?: string; type?: string; category?: string; note?: string
  }
  createdAt: Date
  updatedAt: Date
}

export async function importPresetsCollection(): Promise<Collection<ImportPresetDoc>> {
  const db: Db = await getDb()
  return db.collection<ImportPresetDoc>('import_presets')
}

export async function ensureImportPresetIndexes() {
  const col = await importPresetsCollection()
  try {
    await col.createIndex({ userId: 1, signature: 1 }, { name: 'user_signature' })
  } catch (e) {
    if (!(e as any).message?.includes('already exists')) throw e
  }
}

