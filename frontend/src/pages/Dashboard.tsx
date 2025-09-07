import { useEffect, useMemo, useState } from 'react'
import { api, type Transaction } from '@/lib/api'
import { Card, StatGrid, StatCard, BarChart, ProgressBar } from '@/components/UI';
import { Button, Group, ActionIcon } from '@mantine/core'
import { AddTransactionModal } from '@/components/AddTransactionModal'
import { EditTransactionModal } from '@/components/EditTransactionModal'
import { IconPencil, IconTrash } from '@tabler/icons-react'

export function Dashboard() {
  const [summary, setSummary] = useState<any | null>(null)
  const [budgets, setBudgets] = useState<any | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [weekly, setWeekly] = useState<{ thisWeek: any; lastWeek: any } | null>(null)
  const [recent, setRecent] = useState<Transaction[] | null>(null)
  const [editing, setEditing] = useState<Transaction | null>(null)
  const [showAll, setShowAll] = useState(false)
  const [pageSkip, setPageSkip] = useState(0)
  const [pageLimit] = useState(50)
  const [hasMore, setHasMore] = useState(false)

  async function load(mountedRef?: { current: boolean }) {
    const mounted = mountedRef ? mountedRef.current !== false : true
    setLoading(true)
    try {
      const [s, b, r] = await Promise.all([
        api.summary().catch(() => null),
        api.budgetsStatus().catch(() => null),
        api.listTransactions(10, 0).catch(() => [] as Transaction[]),
      ])
      if (!mounted) return
      setSummary(s)
      setBudgets(b)
      if (!showAll) setRecent(r)
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
      if (!mounted) return
      setWeekly({ thisWeek: tw, lastWeek: lw })
    } catch (e: any) {
      if (!mounted) return
      setError(e.message || 'Failed to load')
    } finally {
      if (mounted) setLoading(false)
    }
  }

  useEffect(() => {
    const mounted = { current: true }
    load(mounted)
    return () => { mounted.current = false }
  }, [])

  async function startFullList() {
    setShowAll(true)
    setPageSkip(0)
    const first = await api.listTransactions(pageLimit, 0).catch(() => [] as Transaction[])
    setRecent(first)
    setHasMore(first.length === pageLimit)
  }

  async function loadMore() {
    const nextSkip = pageSkip + pageLimit
    const more = await api.listTransactions(pageLimit, nextSkip).catch(() => [] as Transaction[])
    setRecent(prev => (prev ? [...prev, ...more] : more))
    setPageSkip(nextSkip)
    setHasMore(more.length === pageLimit)
  }

  async function refreshAll() {
    const count = recent?.length || pageLimit
    const next = await api.listTransactions(count, 0).catch(() => [] as Transaction[])
    setRecent(next)
    setHasMore(next.length % pageLimit === 0)
  }

  const [openExpense, setOpenExpense] = useState(false)
  const [openIncome, setOpenIncome] = useState(false)

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
        <Group gap="sm">
          <Button variant="default" onClick={() => setOpenIncome(true)}>Add Income</Button>
          <Button onClick={() => setOpenExpense(true)}>Add Expense</Button>
        </Group>
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

      {recent && (
        <Card
          title={showAll ? 'All Recent Transactions' : 'Recent Transactions'}
          actions={showAll ? (
            <Group gap="xs">
              <Button variant="default" onClick={() => { setShowAll(false); setPageSkip(0); load() }}>Collapse</Button>
            </Group>
          ) : (
            <Button variant="default" onClick={startFullList}>View more</Button>
          )}
        >
          <table className="table-rounded">
            <thead>
              <tr>
                <th style={{width: 120}}>Date</th>
                <th>Category</th>
                <th>Note</th>
                <th style={{width: 120, textAlign: 'right'}}>Amount</th>
                <th style={{width: 96, textAlign: 'right'}}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {recent.map(tx => {
                const amt = Number(tx.amount || 0)
                const isIncome = tx.type === 'income'
                const sign = isIncome ? '' : '-'
                const d = new Date(tx.date)
                const ds = isNaN(d.getTime()) ? tx.date : d.toLocaleDateString()
                return (
                  <tr key={tx.id}>
                    <td>{ds}</td>
                    <td>{tx.category}</td>
                    <td>{tx.note || ''}</td>
                    <td style={{ textAlign: 'right', color: isIncome ? '#7ee787' : '#ff6b6b' }}>{sign}${Math.abs(amt).toFixed(2)}</td>
                    <td style={{ textAlign: 'right' }}>
                      <ActionIcon variant="subtle" onClick={() => setEditing(tx)} title="Edit" aria-label="Edit">
                        <IconPencil size={16} />
                      </ActionIcon>
                      <ActionIcon variant="subtle" color="red" onClick={async () => {
                        if (!confirm('Delete this transaction?')) return
                        try {
                          await api.deleteTransaction(tx.id)
                          if (showAll) await refreshAll(); else await load()
                        } catch {}
                      }} title="Delete" aria-label="Delete">
                        <IconTrash size={16} />
                      </ActionIcon>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {showAll && (
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 8px' }}>
              <div className="muted">Showing {recent.length} transactions</div>
              {hasMore && (
                <Button variant="default" onClick={loadMore}>Load more</Button>
              )}
            </div>
          )}
        </Card>
      )}

      <EditTransactionModal opened={!!editing} onClose={()=>setEditing(null)} tx={editing} onSaved={()=> showAll ? refreshAll() : load()} />

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

      <AddTransactionModal opened={openExpense} onClose={() => setOpenExpense(false)} type="expense" onAdded={() => load()} />
      <AddTransactionModal opened={openIncome} onClose={() => setOpenIncome(false)} type="income" onAdded={() => load()} />
    </div>
  )
}
