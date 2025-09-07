import { useEffect, useState } from 'react'
import { api } from '@/lib/api'

export function Recurring() {
  const [items, setItems] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setError(null)
    try {
      const data = await api.recurringExpenses()
      setItems(data.recurringExpenses)
    } catch (e: any) {
      setError(e.message || 'Failed to load recurring expenses')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function toggle(id: string) {
    await api.toggleRecurring(id)
    await load()
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Recurring Expenses</h2>
      <div className="card">
        {loading ? (
          <div>Loading…</div>
        ) : error ? (
          <div>{error}</div>
        ) : (
          <table className="table-rounded">
            <thead>
              <tr>
                <th>Name</th>
                <th>Category</th>
                <th>Amount</th>
                <th>Frequency</th>
                <th>Next Due</th>
                <th>Active</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((r: any) => (
                <tr key={r._id}>
                  <td>{r.name}</td>
                  <td>{r.category}</td>
                  <td>${(r.amountCents ? r.amountCents/100 : r.amount).toFixed(2)}</td>
                  <td>{r.frequency}</td>
                  <td>{r.nextDue ? new Date(r.nextDue).toLocaleDateString() : '-'}</td>
                  <td>{r.isActive ? 'Yes' : 'No'}</td>
                  <td><button onClick={() => toggle(r._id)}>Toggle</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
