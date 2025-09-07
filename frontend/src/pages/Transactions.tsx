import { FormEvent, useEffect, useMemo, useState } from 'react'
import { api, Transaction } from '@/lib/api'
import { toast } from '@/lib/toast'
import { Card, StatGrid, StatCard, TrendChart } from '@/components/UI'

export function Transactions() {
  const [items, setItems] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [form, setForm] = useState({ type: 'expense' as 'expense' | 'income', amount: '', category: '', note: '', date: '' })
  const [filter, setFilter] = useState({ type: 'all' as 'all'|'expense'|'income', q: '', start: '', end: '' })
  const [trend, setTrend] = useState<{ label: string; income: number; expenses: number }[] | null>(null)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editForm, setEditForm] = useState<{ type: 'expense'|'income'; amount: string; category: string; note: string; date: string; tags: string }>({ type: 'expense', amount: '', category: '', note: '', date: '', tags: '' })

  async function load() {
    setLoading(true)
    setError(null)
    try {
      const data = await api.listTransactions(50, 0)
      setItems(data)
    } catch (e: any) {
      setError(e.message || 'Failed to load transactions')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const totals = useMemo(() => {
    let income = 0, expenses = 0
    for (const t of items) {
      if (t.type === 'income') income += t.amount; else expenses += t.amount
    }
    return { income, expenses, net: income - expenses, count: items.length }
  }, [items])

  const filtered = useMemo(() => {
    return items.filter(t => (filter.type === 'all' || t.type === filter.type) && (
      !filter.q || (t.category?.toLowerCase().includes(filter.q.toLowerCase()) || (t.note || '').toLowerCase().includes(filter.q.toLowerCase()))
    )).filter(t => {
      if (!filter.start && !filter.end) return true
      const d = new Date(t.date).getTime()
      const s = filter.start ? new Date(filter.start).getTime() : -Infinity
      const e = filter.end ? new Date(filter.end).getTime() : Infinity
      return d >= s && d <= e
    })
  }, [items, filter])

  const categories = useMemo(() => {
    const set = new Set<string>()
    for (const t of items) set.add(t.category)
    return Array.from(set).sort((a,b) => a.localeCompare(b))
  }, [items])

  useEffect(() => {
    // Build monthly trend for selected date range (up to 12 months), else last 6 months
    async function loadTrend() {
      let start: Date
      let end: Date
      if (filter.start) start = new Date(filter.start); else { const n = new Date(); start = new Date(n.getFullYear(), n.getMonth() - 5, 1) }
      if (filter.end) end = new Date(filter.end); else { const n = new Date(); end = new Date(n.getFullYear(), n.getMonth() + 1, 0) }
      // Clamp to month boundaries
      start = new Date(start.getFullYear(), start.getMonth(), 1)
      end = new Date(end.getFullYear(), end.getMonth() + 1, 0, 23, 59, 59, 999)
      const out: { label: string; income: number; expenses: number }[] = []
      let cur = new Date(start)
      let guard = 0
      while (cur <= end && guard++ < 12) {
        const s = new Date(cur.getFullYear(), cur.getMonth(), 1)
        const e = new Date(cur.getFullYear(), cur.getMonth() + 1, 0, 23, 59, 59, 999)
        const summ = await api.summary({ startDate: s.toISOString(), endDate: e.toISOString() })
        out.push({ label: s.toISOString().slice(0,7), income: Number(summ.totalIncome || 0), expenses: Number(summ.totalExpenses || 0) })
        cur = new Date(cur.getFullYear(), cur.getMonth() + 1, 1)
      }
      setTrend(out)
    }
    loadTrend()
  }, [filter.start, filter.end])

  async function add(e: FormEvent) {
    e.preventDefault()
    const amount = parseFloat(form.amount)
    if (!isFinite(amount)) return
    await api.addTransaction({ type: form.type, amount, category: form.category, note: (form.note || null) as any, date: form.date || undefined })
    toast('Transaction added', 'success')
    setForm({ type: 'expense', amount: '', category: '', note: '', date: '' })
    await load()
  }

  async function del(id: string) {
    await api.deleteTransaction(id)
    toast('Transaction deleted', 'info')
    await load()
  }

  async function loadMore() {
    try {
      const data = await api.listTransactions(50, items.length)
      if (data.length > 0) setItems(prev => [...prev, ...data])
      else toast('No more transactions', 'info')
    } catch (e: any) {
      toast(e.message || 'Failed to load more', 'error')
    }
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Transactions</h2>

      <Card>
        <StatGrid>
          <StatCard label="Count" value={totals.count} />
          <StatCard label="Income" value={`$${totals.income.toFixed(2)}`} />
          <StatCard label="Expenses" value={`$${totals.expenses.toFixed(2)}`} />
          <StatCard label="Net" value={`$${totals.net.toFixed(2)}`} />
        </StatGrid>
      </Card>

      <Card title="Add Transaction">
        <form className="row" onSubmit={add} style={{ gap: 8, flexWrap: 'wrap' }}>
          <select value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value as any }))}>
            <option value="expense">Expense</option>
            <option value="income">Income</option>
          </select>
          <input placeholder="Amount" type="number" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} />
          <input placeholder="Category" list="categories" value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))} />
          <datalist id="categories">
            {categories.map(c => <option key={c} value={c} />)}
          </datalist>
          <input placeholder="Note" value={form.note} onChange={e => setForm(f => ({ ...f, note: e.target.value }))} />
          <input placeholder="Date (optional)" type="date" value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} />
          <button type="submit">Add</button>
        </form>
      </Card>

      <Card title="All Transactions" actions={
        <div className="row" style={{ gap: 8 }}>
          <select value={filter.type} onChange={e => setFilter(f => ({ ...f, type: e.target.value as any }))}>
            <option value="all">All</option>
            <option value="expense">Expense</option>
            <option value="income">Income</option>
          </select>
          <select value={filter.q} onChange={e => setFilter(f => ({ ...f, q: e.target.value }))}>
            <option value="">All categories</option>
            {categories.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <input type="date" value={filter.start} onChange={e => setFilter(f => ({ ...f, start: e.target.value }))} />
          <input type="date" value={filter.end} onChange={e => setFilter(f => ({ ...f, end: e.target.value }))} />
        </div>
      }>
        {loading ? (
          <div>Loading…</div>
        ) : error ? (
          <div>{error}</div>
        ) : (
          <table className="table-rounded">
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Category</th>
                <th>Amount</th>
                <th>Note</th>
                <th>Tags</th>
                <th>Receipt</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(tx => (
                editingId === tx.id ? (
                  <tr key={tx.id}>
                    <td><input type="date" value={editForm.date} onChange={e => setEditForm(f => ({ ...f, date: e.target.value }))} /></td>
                    <td>
                      <select value={editForm.type} onChange={e => setEditForm(f => ({ ...f, type: e.target.value as any }))}>
                        <option value="expense">expense</option>
                        <option value="income">income</option>
                      </select>
                    </td>
                    <td><input value={editForm.category} onChange={e => setEditForm(f => ({ ...f, category: e.target.value }))} /></td>
                    <td><input type="number" step="0.01" value={editForm.amount} onChange={e => setEditForm(f => ({ ...f, amount: e.target.value }))} /></td>
                    <td><input value={editForm.note} onChange={e => setEditForm(f => ({ ...f, note: e.target.value }))} /></td>
                    <td><input placeholder="comma,separated" value={editForm.tags} onChange={e => setEditForm(f => ({ ...f, tags: e.target.value }))} /></td>
                    <td className="muted">—</td>
                    <td>
                      <div className="row" style={{ gap: 8 }}>
                        <button className="btn-ghost" onClick={async () => {
                          const payload = { type: editForm.type, amount: parseFloat(editForm.amount || '0'), category: editForm.category, note: editForm.note || null, date: editForm.date ? new Date(editForm.date).toISOString() : undefined, tags: editForm.tags.split(',').map(s => s.trim()).filter(Boolean) }
                          await api.updateTransaction(tx.id, payload as any)
                          toast('Transaction updated', 'success')
                          setEditingId(null)
                          await load()
                        }}>Save</button>
                        <button className="btn-ghost" onClick={() => setEditingId(null)}>Cancel</button>
                      </div>
                    </td>
                  </tr>
                ) : (
                  <tr key={tx.id}>
                    <td>{new Date(tx.date).toLocaleDateString()}</td>
                    <td>{tx.type}</td>
                    <td>{tx.category}</td>
                    <td>${tx.amount.toFixed(2)}</td>
                    <td className="muted">{tx.note || ''}</td>
                    <td>{(tx.tags || []).map(t => <span key={t} className="chip" style={{ marginRight: 4 }}>{t}</span>)}</td>
                    <td>
                      {tx.receiptUrl ? (
                        <div className="row" style={{ gap: 6 }}>
                          <a href={tx.receiptUrl} target="_blank" rel="noreferrer">View</a>
                          <button className="btn-ghost" onClick={async () => { await api.deleteReceipt(tx.id); toast('Receipt removed', 'info'); await load() }}>Remove</button>
                        </div>
                      ) : (
                        <label className="btn-ghost" style={{ cursor: 'pointer' }}>
                          Upload
                          <input type="file" accept="image/*,application/pdf" style={{ display: 'none' }} onChange={async e => { const f = e.target.files?.[0]; if (f) { await api.uploadReceipt(tx.id, f); toast('Receipt uploaded', 'success'); await load() } }} />
                        </label>
                      )}
                    </td>
                    <td>
                      <div className="row" style={{ gap: 8 }}>
                        <button className="btn-ghost" onClick={() => { setEditingId(tx.id); setEditForm({ type: tx.type, amount: String(tx.amount), category: tx.category, note: tx.note || '', date: tx.date.slice(0,10), tags: (tx.tags || []).join(',') }) }}>Edit</button>
                        <button className="btn-ghost" onClick={() => del(tx.id)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                )
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <div className="row" style={{ justifyContent: 'center' }}>
        <button className="btn-ghost" onClick={loadMore}>Load more</button>
      </div>

      {trend && (
        <Card title="Monthly Trend (6 mo)">
          <TrendChart data={trend} />
        </Card>
      )}

      <Card title="Export">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button className="btn-ghost" onClick={async () => {
            const blob = await api.exportTransactionsCSV({ startDate: filter.start || undefined, endDate: filter.end || undefined, category: filter.q || undefined, type: filter.type === 'all' ? undefined : filter.type })
            const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = 'transactions.csv'; a.click(); URL.revokeObjectURL(url)
          }}>Export CSV</button>
          <button className="btn-ghost" onClick={async () => {
            const blob = await api.exportTransactionsExcel({ startDate: filter.start || undefined, endDate: filter.end || undefined, category: filter.q || undefined, type: filter.type === 'all' ? undefined : filter.type })
            const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = 'transactions.xlsx'; a.click(); URL.revokeObjectURL(url)
          }}>Export Excel</button>
        </div>
      </Card>

      <CategoryTotals items={filtered} />
    </div>
  )
}

function CategoryTotals({ items }: { items: Transaction[] }) {
  const totals = useMemo(() => {
    const map = new Map<string, number>()
    for (const t of items) map.set(t.category, (map.get(t.category) || 0) + t.amount)
    return Array.from(map.entries()).map(([label, value]) => ({ label, value })).sort((a,b) => b.value - a.value).slice(0, 10)
  }, [items])
  if (totals.length === 0) return null
  return (
    <Card title="Top Categories (current filter)">
      <div style={{ marginTop: 4 }}>
        {/* reuse BarChart styles: inline to avoid circular import */}
        <div className="barchart">
          {totals.map(d => (
            <div key={d.label} className="bar-row">
              <div className="bar-label">{d.label}</div>
              <div className="bar-track"><div className="bar-fill" style={{ width: `${(d.value / Math.max(1, Math.max(...totals.map(x => x.value)))) * 100}%` }} /></div>
              <div className="bar-value">${d.value.toFixed(0)}</div>
            </div>
          ))}
        </div>
      </div>
    </Card>
  )
}
