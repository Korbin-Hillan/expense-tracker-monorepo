import { useEffect, useState } from 'react'
import { api } from '@/lib/api'
import { Card } from '@/components/UI'
import { toast } from '@/lib/toast'

export function DuplicatesPage() {
  const [groups, setGroups] = useState<{ key: string; items: { id: string; date: string; amount: number; note: string }[] }[]>([])
  const [loading, setLoading] = useState(false)

  async function load() {
    setLoading(true)
    try {
      const res = await api.listDuplicates()
      setGroups(res.groups || [])
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => { load() }, [])

  async function resolve(keepId: string, deleteIds: string[]) {
    const n = await api.resolveDuplicates(keepId, deleteIds)
    toast(`Removed ${n.deleted} duplicate(s)`, 'success')
    await load()
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Duplicates</h2>
          <p className="page-subtitle">Review and resolve possible duplicate transactions.</p>
        </div>
        <button className="btn-ghost" onClick={load}>Refresh</button>
      </div>

      <Card>
        {loading ? <div>Loading…</div> : groups.length === 0 ? <div className="muted">No duplicates detected.</div> : (
          <table className="table-rounded">
            <thead>
              <tr><th>Date</th><th>Amount</th><th>Note</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {groups.map(g => (
                <tr key={g.key}>
                  <td>{new Date(g.items[0].date).toLocaleDateString()}</td>
                  <td>${g.items[0].amount.toFixed(2)}</td>
                  <td className="muted">{g.items[0].note}</td>
                  <td>
                    <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
                      {g.items.map((it, idx) => (
                        <button key={it.id} className="btn-ghost" onClick={() => resolve(it.id, g.items.filter(x => x.id !== it.id).map(x => x.id))}>Keep #{idx+1}</button>
                      ))}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  )
}

