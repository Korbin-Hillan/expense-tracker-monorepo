import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { requireAppJWT } from '../middleware/auth.ts';
import { budgetsCollection } from '../database/budgets.ts';
import { transactionsCollection } from '../database/transactions.ts';

export const budgetsRouter = Router();

// GET /api/budgets - list budgets for the user
budgetsRouter.get('/api/budgets', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const col = await budgetsCollection();
    const docs = await col.find({ userId }).sort({ category: 1 }).toArray();
    res.json(docs.map(d => ({ id: String(d._id), category: d.category, monthly: d.monthlyCents / 100 })));
  } catch (e) {
    res.status(500).json({ error: 'failed_to_list_budgets' });
  }
});

// PUT /api/budgets - replace budgets list
budgetsRouter.put('/api/budgets', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const items = Array.isArray(req.body?.budgets) ? req.body.budgets : [];
    if (!Array.isArray(items)) { res.status(400).json({ error: 'budgets_required' }); return; }
    const col = await budgetsCollection();
    // Normalize categories and validate
    const norm = (s: string) => {
      const t = String(s || '').trim();
      if (!t) return 'Overall';
      if (t.toLowerCase() === 'overall') return 'Overall';
      // Title-case simple
      return t
        .toLowerCase()
        .split(/\s+/)
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
    };
    // Deduplicate by category (last write wins)
    const byCat = new Map<string, number>();
    for (const it of items) {
      const cat = norm(it.category);
      const monthly = Number(it.monthly);
      if (!isFinite(monthly) || monthly < 0) continue;
      byCat.set(cat, monthly);
    }
    // Upsert each normalized item
    const ops = Array.from(byCat.entries()).map(([cat, monthly]) => ({
      updateOne: {
        filter: { userId, category: cat },
        update: {
          $set: {
            monthlyCents: Math.max(0, Math.round(Number(monthly || 0) * 100)),
            updatedAt: new Date(),
          },
          $setOnInsert: { userId, category: cat, createdAt: new Date() },
        },
        upsert: true,
      },
    }));
    if (ops.length) await col.bulkWrite(ops, { ordered: false });
    const docs = await col.find({ userId }).toArray();
    res.json({ success: true, budgets: docs.map(d => ({ id: String(d._id), category: d.category, monthly: d.monthlyCents / 100 })) });
  } catch (e) {
    res.status(500).json({ error: 'failed_to_update_budgets' });
  }
});

// GET /api/budgets/status - current month spending vs budgets
budgetsRouter.get('/api/budgets/status', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const now = new Date();
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0, 0, 0));
    const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0, 23, 59, 59));
    const txCol = await transactionsCollection();
    const txs = await txCol.find({ userId, type: 'expense', date: { $gte: start, $lte: end } }).toArray();
    const spentByCat = new Map<string, number>();
    for (const t of txs) {
      const amt = (t as any).amountCents ? (t as any).amountCents / 100 : (t as any).amount || 0;
      spentByCat.set(t.category, (spentByCat.get(t.category) ?? 0) + amt);
      spentByCat.set('Overall', (spentByCat.get('Overall') ?? 0) + amt);
    }
    const col = await budgetsCollection();
    const budgets = await col.find({ userId }).toArray();
    const status = budgets.map(b => {
      const monthly = b.monthlyCents / 100;
      const spent = spentByCat.get(b.category) ?? 0;
      const pct = monthly > 0 ? Math.min(1, spent / monthly) : 0;
      let level: 'ok'|'warn'|'danger' = 'ok';
      if (pct >= 1) level = 'danger';
      else if (pct >= 0.8) level = 'warn';
      return { category: b.category, monthly, spent, remaining: Math.max(0, monthly - spent), level };
    });
    res.json({ month: start.toISOString().slice(0,7), status });
  } catch (e) {
    res.status(500).json({ error: 'failed_to_compute_status' });
  }
});
