import { useEffect, useMemo, useState } from 'react'
import { api } from '@/lib/api'
import { toast } from '@/lib/toast'
import { Card, StatGrid, StatCard, BarChart } from '@/components/UI'

type Sub = { note: string; count: number; avg: number; monthlyEstimate: number; frequency: string }

export function Subscriptions() {
  const [subs, setSubs] = useState<Sub[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [exporting, setExporting] = useState(false)

  async function load() {
    setLoading(true)
    setError(null)
    try {
      const data = await api.subscriptions()
      setSubs(data.subs)
    } catch (e: any) {
      setError(e.message || 'Failed to load subscriptions')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const totals = useMemo(() => {
    const monthly = subs.reduce((a, b) => a + (b.monthlyEstimate || 0), 0)
    const count = subs.length
    const avg = count ? monthly / count : 0
    return { monthly, count, avg }
  }, [subs])
  const byFreq = useMemo(() => {
    const map = new Map<string, number>()
    for (const s of subs) map.set(s.frequency || 'unknown', (map.get(s.frequency || 'unknown') || 0) + s.monthlyEstimate)
    return Array.from(map.entries()).map(([label, value]) => ({ label, value })).sort((a,b) => b.value - a.value)
  }, [subs])
  const topSubs = useMemo(() => subs.slice().sort((a,b) => b.monthlyEstimate - a.monthlyEstimate).slice(0, 6).map(s => ({ label: s.note, value: s.monthlyEstimate })), [subs])

  async function setPref(note: string, pref: { ignore?: boolean; cancel?: boolean }) {
    await api.setSubscriptionPref(note, pref)
    toast(pref.ignore ? 'Ignored subscription' : 'Marked for cancel', 'success')
    await load()
  }

  async function exportCSV() {
    setExporting(true)
    try {
      const blob = await api.exportSubscriptionsCSV()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'subscriptions.csv'
      a.click()
      URL.revokeObjectURL(url)
      toast('CSV exported', 'success')
    } finally {
      setExporting(false)
    }
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Subscriptions</h2>

      <Card
        title={<span>Overview</span>}
        actions={<button onClick={exportCSV} disabled={exporting}>{exporting ? 'Exporting…' : 'Export CSV'}</button>}
      >
        <StatGrid>
          <StatCard label="Total Monthly" value={`$${totals.monthly.toFixed(2)}`} />
          <StatCard label="Subscriptions" value={totals.count} />
          <StatCard label="Avg per Sub" value={`$${totals.avg.toFixed(2)}`} />
          <StatCard label="Top Freq" value={subs[0]?.frequency || '—'} />
        </StatGrid>
      </Card>

      <Card title="Detected Subscriptions">
        {loading ? (
          <div>Loading…</div>
        ) : error ? (
          <div>{error}</div>
        ) : (
          <table className="table-rounded">
            <thead>
              <tr>
                <th>Note</th>
                <th>Monthly</th>
                <th>Avg</th>
                <th>Count</th>
                <th>Freq</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {subs.map(s => (
                <tr key={s.note}>
                  <td>{s.note}</td>
                  <td>${s.monthlyEstimate.toFixed(2)}</td>
                  <td>${s.avg.toFixed(2)}</td>
                  <td>{s.count}</td>
                  <td><span className="chip blue">{s.frequency || '—'}</span></td>
                  <td>
                    <div className="row" style={{ gap: 8 }}>
                      <button className="btn-ghost" onClick={() => setPref(s.note, { ignore: true })}>Ignore</button>
                      <button className="btn-ghost" onClick={() => setPref(s.note, { cancel: true })}>Cancel</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      {byFreq.length > 0 && (
        <Card title="Totals by Frequency">
          <BarChart data={byFreq} />
        </Card>
      )}
      {topSubs.length > 0 && (
        <Card title="Top Subscriptions (Monthly Estimate)">
          <BarChart data={topSubs} />
        </Card>
      )}
    </div>
  )
}
