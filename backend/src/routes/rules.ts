import { Router } from 'express'
import { ObjectId } from 'mongodb'
import { requireAppJWT } from '../middleware/auth.ts'
import { rulesCollection, BudgetRuleDoc } from '../database/rules.ts'
import { transactionsCollection } from '../database/transactions.ts'

export const rulesRouter = Router()

// List rules
rulesRouter.get('/api/rules', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const col = await rulesCollection()
  const rules = await col.find({ userId }).sort({ order: 1, createdAt: 1 }).toArray()
  res.json({ rules })
})

// Create / Update rule
rulesRouter.post('/api/rules', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const { id, name, order, enabled, when, set } = req.body ?? {}
  if (!name || !when?.field || !when?.type || !when?.value) { res.status(400).json({ error: 'invalid_payload' }); return }
  const rule: Partial<BudgetRuleDoc> = {
    name: String(name).trim(),
    order: typeof order === 'number' ? order : undefined,
    enabled: enabled !== false,
    when: { field: when.field, type: when.type, value: String(when.value) },
    set: { category: set?.category, tags: Array.isArray(set?.tags) ? set.tags.slice(0, 10) : undefined },
    updatedAt: new Date(),
  }
  const col = await rulesCollection()
  if (id && ObjectId.isValid(String(id))) {
    const _id = new ObjectId(String(id))
    await col.updateOne({ _id, userId }, { $set: rule })
    const doc = await col.findOne({ _id, userId })
    res.json({ rule: doc })
  } else {
    const doc: BudgetRuleDoc = { ...(rule as any), userId, createdAt: new Date(), enabled: rule.enabled ?? true, name: rule.name as string, when: rule.when as any, set: rule.set as any }
    const r = await col.insertOne(doc)
    const saved = await col.findOne({ _id: r.insertedId })
    res.status(201).json({ rule: saved })
  }
})

// Delete
rulesRouter.delete('/api/rules/:id', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const id = String(req.params.id)
  if (!ObjectId.isValid(id)) { res.status(400).json({ error: 'bad_id' }); return }
  const col = await rulesCollection()
  await col.deleteOne({ _id: new ObjectId(id), userId })
  res.json({ success: true })
})

// Apply rules to all transactions
rulesRouter.post('/api/rules/apply', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const col = await rulesCollection()
  const rules = await col.find({ userId, enabled: true }).sort({ order: 1, createdAt: 1 }).toArray()
  const txCol = await transactionsCollection()
  const cursor = txCol.find({ userId })
  let updated = 0
  for await (const tx of cursor) {
    const u = computeUpdate(tx, rules)
    if (u) {
      await txCol.updateOne({ _id: tx._id }, { $set: { ...u, updatedAt: new Date() } })
      updated++
    }
  }
  res.json({ updated })
})

function computeUpdate(tx: any, rules: BudgetRuleDoc[]): Record<string, any> | null {
  for (const r of rules) {
    const fieldVal = String((tx as any)[r.when.field] || '')
    let match = false
    if (r.when.type === 'contains') {
      match = fieldVal.toLowerCase().includes(r.when.value.toLowerCase())
    } else if (r.when.type === 'regex') {
      try { match = new RegExp(r.when.value, 'i').test(fieldVal) } catch { match = false }
    }
    if (match) {
      const upd: Record<string, any> = {}
      if (r.set.category) upd.category = r.set.category
      if (Array.isArray(r.set.tags) && r.set.tags.length) {
        const cur = Array.isArray(tx.tags) ? tx.tags : []
        const merged = Array.from(new Set([...cur, ...r.set.tags])).slice(0, 20)
        upd.tags = merged
      }
      if (Object.keys(upd).length) return upd
    }
  }
  return null
}

