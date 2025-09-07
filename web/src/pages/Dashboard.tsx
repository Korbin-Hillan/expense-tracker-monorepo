import { useEffect, useMemo, useState } from 'react'
import { api } from '@/lib/api'
import { Card, StatGrid, StatCard, BarChart, ProgressBar, TrendChart } from '@/components/UI'

export function Dashboard() {
  const [summary, setSummary] = useState<any | null>(null)
  const [budgets, setBudgets] = useState<any | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [weekly, setWeekly] = useState<{ thisWeek: any; lastWeek: any } | null>(null)

  useEffect(() => {
    let mounted = true
    async function run() {
      setLoading(true)
      try {
        const [s, b] = await Promise.all([api.summary().catch(() => null), api.budgetsStatus().catch(() => null)])
        if (!mounted) return
        setSummary(s)
        setBudgets(b)
        // Week over week
        const now = new Date()
        const weekStart = new Date(now); weekStart.setDate(now.getDate() - now.getDay())
        const weekEnd = new Date(weekStart); weekEnd.setDate(weekStart.getDate() + 6); weekEnd.setHours(23,59,59,999)
        const lastWeekEnd = new Date(weekStart); lastWeekEnd.setDate(weekStart.getDate() - 1)
        const lastWeekStart = new Date(lastWeekEnd); lastWeekStart.setDate(lastWeekEnd.getDate() - 6); lastWeekStart.setHours(0,0,0,0)
        const [tw, lw] = await Promise.all([
          api.summary({ startDate: weekStart.toISOString(), endDate: weekEnd.toISOString() }),
          api.summary({ startDate: lastWeekStart.toISOString(), endDate: lastWeekEnd.toISOString() })
        ])
        setWeekly({ thisWeek: tw, lastWeek: lw })
      } catch (e: any) {
        if (!mounted) return
        setError(e.message || 'Failed to load')
      } finally {
        if (mounted) setLoading(false)
      }
    }
    run()
    return () => { mounted = false }
  }, [])

  const topCategories = useMemo(() => {
    if (!summary?.categorySummary) return [] as { label: string; value: number }[]
    const entries = Object.entries(summary.categorySummary) as [string, { count: number; total: number }][]
    return entries
      .map(([label, v]) => ({ label, value: v.total }))
      .sort((a, b) => b.value - a.value)
      .slice(0, 6)
  }, [summary])

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Dashboard</h2>
          <p className="page-subtitle">Overview of your spending, income, and budgets.</p>
        </div>
      </div>
      {error && <Card><div>{error}</div></Card>}
      {loading && <Card><div>Loading…</div></Card>}

      {summary && (
        <Card>
          <StatGrid>
            <StatCard label="Transactions" value={summary.totalTransactions} hint={`${summary.dateRange?.from} → ${summary.dateRange?.to}`} />
            <StatCard label="Income" value={`$${Number(summary.totalIncome || 0).toFixed(2)}`} />
            <StatCard label="Expenses" value={`$${Number(summary.totalExpenses || 0).toFixed(2)}`} />
            <StatCard label="Net" value={`$${Number(summary.netAmount || 0).toFixed(2)}`} hint={Number(summary.netAmount) >= 0 ? 'Positive' : 'Negative'} />
          </StatGrid>
        </Card>
      )}

      {topCategories.length > 0 && (
        <Card title="Top Categories">
          <BarChart data={topCategories} />
        </Card>
      )}

      {budgets?.status && (
        <Card title={`Budgets · ${budgets.month}`}>
          <table className="table-rounded">
            <thead>
              <tr><th>Category</th><th style={{width: 140}}>Progress</th><th>Spent</th><th>Monthly</th><th>Level</th></tr>
            </thead>
            <tbody>
              {budgets.status.map((b: any) => {
                const spent = Number(b.spent || 0)
                const monthly = Number(b.monthly || 0)
                return (
                  <tr key={b.category}>
                    <td>{b.category}</td>
                    <td><ProgressBar value={spent} max={monthly} /></td>
                    <td>${spent.toFixed(2)}</td>
                    <td>${monthly.toFixed(2)}</td>
                    <td style={{ textTransform: 'capitalize' }}>{b.level}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Card>
      )}

      {weekly && (
        <Card title="Week Over Week">
          <StatGrid>
            <StatCard label="This Week Income" value={`$${Number(weekly.thisWeek?.totalIncome || 0).toFixed(2)}`} />
            <StatCard label="This Week Expenses" value={`$${Number(weekly.thisWeek?.totalExpenses || 0).toFixed(2)}`} />
            <StatCard label="Last Week Income" value={`$${Number(weekly.lastWeek?.totalIncome || 0).toFixed(2)}`} />
            <StatCard label="Last Week Expenses" value={`$${Number(weekly.lastWeek?.totalExpenses || 0).toFixed(2)}`} />
          </StatGrid>
        </Card>
      )}
    </div>
  )
}
