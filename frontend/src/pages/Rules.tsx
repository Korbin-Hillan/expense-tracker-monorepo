import { useEffect, useState } from 'react'
import { api } from '@/lib/api'
import { Card } from '@/components/UI'
import { toast } from '@/lib/toast'

type Rule = { _id?: string; id?: string; name: string; order?: number; enabled: boolean; when: { field: 'description'|'note'|'merchantCanonical'; type: 'contains'|'regex'; value: string }; set: { category?: string; tags?: string[] } }

export function RulesPage() {
  const [rules, setRules] = useState<Rule[]>([])
  const [loading, setLoading] = useState(false)
  const [draft, setDraft] = useState<Rule>({ name: '', enabled: true, when: { field: 'description', type: 'contains', value: '' }, set: {} })

  async function load() {
    setLoading(true)
    try {
      const res = await api.listRules()
      const list = (res.rules || []).map((r: any) => ({ ...r, id: r._id || r.id }))
      setRules(list)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => { load() }, [])

  async function save() {
    try {
      const payload: any = { ...draft, set: { ...draft.set, tags: draft.set.tags?.filter(Boolean) } }
      await api.saveRule(payload)
      toast('Rule saved', 'success')
      setDraft({ name: '', enabled: true, when: { field: 'description', type: 'contains', value: '' }, set: {} })
      await load()
    } catch (e: any) { toast(e.message || 'Failed to save rule', 'error') }
  }

  async function remove(id?: string) {
    if (!id) return
    await api.deleteRule(id)
    toast('Rule deleted', 'info')
    await load()
  }

  async function applyNow() {
    const res = await api.applyRules()
    toast(`Updated ${res.updated} transactions`, 'success')
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Rules</h2>
          <p className="page-subtitle">Automatically categorize and tag transactions based on description, note, or merchant.</p>
        </div>
        <button className="btn-ghost" onClick={applyNow}>Apply Now</button>
      </div>

      <Card title="New Rule">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <input placeholder="Name" value={draft.name} onChange={e => setDraft(d => ({ ...d, name: e.target.value }))} />
          <select value={draft.when.field} onChange={e => setDraft(d => ({ ...d, when: { ...d.when, field: e.target.value as any } }))}>
            <option value="description">Description</option>
            <option value="note">Note</option>
            <option value="merchantCanonical">Merchant</option>
          </select>
          <select value={draft.when.type} onChange={e => setDraft(d => ({ ...d, when: { ...d.when, type: e.target.value as any } }))}>
            <option value="contains">Contains</option>
            <option value="regex">Regex</option>
          </select>
          <input placeholder="Match value" value={draft.when.value} onChange={e => setDraft(d => ({ ...d, when: { ...d.when, value: e.target.value } }))} />
          <input placeholder="Set category (optional)" value={draft.set.category || ''} onChange={e => setDraft(d => ({ ...d, set: { ...d.set, category: e.target.value || undefined } }))} />
          <input placeholder="Add tags (comma separated)" value={(draft.set.tags || []).join(',')} onChange={e => setDraft(d => ({ ...d, set: { ...d.set, tags: e.target.value.split(',').map(s => s.trim()).filter(Boolean) } }))} />
          <label className="row" style={{ gap: 6 }}>
            <input type="checkbox" checked={draft.enabled} onChange={e => setDraft(d => ({ ...d, enabled: e.target.checked }))} /> Enabled
          </label>
          <button onClick={save}>Save Rule</button>
        </div>
      </Card>

      <Card title="Existing Rules">
        {loading ? <div>Loading…</div> : (
          <table className="table-rounded">
            <thead>
              <tr><th>Name</th><th>When</th><th>Set</th><th>Enabled</th><th></th></tr>
            </thead>
            <tbody>
              {rules.map(r => (
                <tr key={r.id}>
                  <td>{r.name}</td>
                  <td>{r.when.field} {r.when.type} "{r.when.value}"</td>
                  <td>
                    {(r.set.category ? <span className="chip" style={{ marginRight: 6 }}>Category: {r.set.category}</span> : null)}
                    {(r.set.tags || []).map(t => <span key={t} className="chip" style={{ marginRight: 4 }}>{t}</span>)}
                  </td>
                  <td>{r.enabled ? 'Yes' : 'No'}</td>
                  <td><button className="btn-ghost" onClick={() => remove(r.id)}>Delete</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  )
}

