import { FormEvent, useEffect, useMemo, useState } from 'react'
import { api } from '@/lib/api'
import { toast } from '@/lib/toast'
import { Card, ProgressBar } from '@/components/UI'

type BudgetRow = { id?: string; category: string; monthly: number }

export function Budgets() {
  const [rows, setRows] = useState<BudgetRow[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [status, setStatus] = useState<any | null>(null)
  const [summary, setSummary] = useState<any | null>(null)

  async function load() {
    setLoading(true)
    setError(null)
    try {
      const [list, s, sum] = await Promise.all([api.listBudgets(), api.budgetsStatus().catch(() => null), api.summary().catch(() => null)])
      setRows(list)
      setStatus(s)
      setSummary(sum)
    } catch (e: any) {
      setError(e.message || 'Failed to load budgets')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  function addRow() {
    setRows(r => [...r, { category: '', monthly: 0 }])
  }

  function removeRow(i: number) {
    setRows(r => r.filter((_, idx) => idx !== i))
  }

  async function onSave(e: FormEvent) {
    e.preventDefault()
    setSaving(true)
    try {
      // validation
      const seen = new Set<string>()
      const payload = rows.map(r => ({ category: r.category.trim(), monthly: Number(r.monthly) || 0 }))
        .filter(r => {
          if (!r.category) return false
          const lc = r.category.toLowerCase()
          if (seen.has(lc)) return false
          seen.add(lc); return true
        })
        .map(r => ({ ...r, monthly: Math.max(0, r.monthly) }))
      await api.putBudgets(payload)
      await load()
      toast('Budgets saved', 'success')
    } catch (e: any) {
      setError(e.message || 'Failed to save budgets')
      toast('Failed to save budgets', 'error')
    } finally {
      setSaving(false)
    }
  }

  const suggestions = useMemo(() => {
    if (!summary?.categorySummary) return [] as string[]
    const existing = new Set(rows.map(r => r.category.toLowerCase()))
    return Object.keys(summary.categorySummary).filter(k => !existing.has(k.toLowerCase())).slice(0, 8)
  }, [summary, rows])

  const totalMonthly = useMemo(() => rows.reduce((a, b) => a + (Number(b.monthly) || 0), 0), [rows])

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Budgets</h2>
      {error && <Card><div>{error}</div></Card>}

      <Card title="Budgets Editor" actions={<div>Total Monthly: <strong>${totalMonthly.toFixed(2)}</strong></div>}>
        {loading ? (
          <div>Loading…</div>
        ) : (
          <form className="col" onSubmit={onSave}>
            <table className="table-rounded">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Monthly ($)</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={i}>
                    <td><input value={r.category} onChange={e => setRows(rs => rs.map((x, idx) => idx === i ? { ...x, category: e.target.value } : x))} /></td>
                    <td><input type="number" step="0.01" value={r.monthly} onChange={e => setRows(rs => rs.map((x, idx) => idx === i ? { ...x, monthly: parseFloat(e.target.value || '0') } : x))} /></td>
                    <td><button className="btn-ghost" type="button" onClick={() => removeRow(i)}>Remove</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
              <button type="button" onClick={addRow}>Add Category</button>
              <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save Budgets'}</button>
              {suggestions.length > 0 && (
                <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
                  <span className="muted">Suggestions:</span>
                  {suggestions.map(c => (
                    <button key={c} className="btn-ghost" type="button" onClick={() => setRows(r => [...r, { category: c, monthly: 0 }])}>{c}</button>
                  ))}
                </div>
              )}
            </div>
          </form>
        )}
      </Card>

      {status && status.status && (
        <Card title={`This Month · ${status.month}`}>
          <table className="table-rounded">
            <thead>
              <tr><th>Category</th><th style={{width: 220}}>Progress</th><th>Spent</th><th>Monthly</th><th>Level</th></tr>
            </thead>
            <tbody>
              {status.status.map((s: any) => {
                const spent = Number(s.spent || 0)
                const monthly = Number(s.monthly || 0)
                return (
                  <tr key={s.category}>
                    <td>{s.category}</td>
                    <td><ProgressBar value={spent} max={monthly} /></td>
                    <td>${spent.toFixed(2)}</td>
                    <td>${monthly.toFixed(2)}</td>
                    <td style={{ textTransform: 'capitalize' }}>{s.level}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Card>
      )}
    </div>
  )
}
