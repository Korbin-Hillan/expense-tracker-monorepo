import { getDb } from './databaseConnection.js'
import { ObjectId, Db, Collection } from 'mongodb'

export type RuleWhen = {
  field: 'description' | 'note' | 'merchantCanonical'
  type: 'contains' | 'regex'
  value: string
}

export type RuleSet = {
  category?: string
  tags?: string[]
}

export type BudgetRuleDoc = {
  _id?: ObjectId
  userId: ObjectId
  name: string
  order?: number
  enabled: boolean
  when: RuleWhen
  set: RuleSet
  createdAt: Date
  updatedAt: Date
}

export async function rulesCollection(): Promise<Collection<BudgetRuleDoc>> {
  const db: Db = await getDb()
  return db.collection<BudgetRuleDoc>('rules')
}

export async function ensureRuleIndexes() {
  const col = await rulesCollection()
  try {
    await col.createIndex({ userId: 1, order: 1 }, { name: 'user_order' })
  } catch (e) {
    if (!(e as any).message?.includes('already exists')) throw e
  }
}

