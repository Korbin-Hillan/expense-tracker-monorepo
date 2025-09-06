import { getDb } from './databaseConnection.js'
import { ObjectId, Db, Collection } from 'mongodb'

export type IntegrationDoc = {
  _id?: ObjectId
  userId: ObjectId
  provider: 'plaid'|'google'|'notion'|'sheets'
  accessToken?: string
  refreshToken?: string
  scopes?: string[]
  expiresAt?: Date
  extra?: Record<string, any>
  createdAt: Date
  updatedAt: Date
}

export async function integrationsCollection(): Promise<Collection<IntegrationDoc>> {
  const db: Db = await getDb()
  return db.collection<IntegrationDoc>('integrations')
}

export async function ensureIntegrationIndexes() {
  const col = await integrationsCollection()
  try { await col.createIndex({ userId: 1, provider: 1 }, { name: 'user_provider', unique: true }) } catch (e) { if (!(e as any).message?.includes('already exists')) throw e }
}

