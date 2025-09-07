import { useMemo, useState } from 'react'
import { api } from '@/lib/api'
import { Card } from '@/components/UI'
import { toast } from '@/lib/toast'

type Mapping = { date?: string; description?: string; amount?: string; type?: string; category?: string; note?: string }

export function ImportPage() {
  const [file, setFile] = useState<File | null>(null)
  const [columns, setColumns] = useState<string[]>([])
  const [mapping, setMapping] = useState<Mapping>({})
  const [loading, setLoading] = useState(false)
  const [preview, setPreview] = useState<any[] | null>(null)
  const [stats, setStats] = useState<{ totalRows?: number; duplicates?: number } | null>(null)
  const [skipDuplicates, setSkipDuplicates] = useState(true)
  const [overwriteDuplicates, setOverwriteDuplicates] = useState(false)
  const [useAI, setUseAI] = useState(true)
  const [applyAICategory, setApplyAICategory] = useState(false)
  const [signature, setSignature] = useState('')
  const [presetName, setPresetName] = useState('')

  const requiredOk = useMemo(() => Boolean(mapping.date && mapping.description && mapping.amount), [mapping])

  async function onPick(f: File) {
    try {
      setFile(f)
      setPreview(null); setStats(null)
      const res = await api.importColumns(f)
      setColumns(res.columns || [])
      const sm = res.suggestedMapping || {}
      setMapping(m => ({ ...m, date: sm.date || m.date, description: sm.description || m.description, amount: sm.amount || m.amount, type: sm.type, category: sm.category, note: sm.note }))
      setSignature(res.signature || '')
      if (res.preset?.mapping) {
        setMapping(res.preset.mapping)
        setPresetName(res.preset.name || '')
        toast(`Preset applied: ${res.preset.name}`, 'info')
      }
    } catch (e: any) {
      toast(e.message || 'Failed to inspect file', 'error')
    }
  }

  async function doPreview() {
    if (!file) return
    if (!requiredOk) { toast('Map Date, Description, Amount columns first', 'error'); return }
    setLoading(true)
    try {
      const res = await api.importPreview(file, mapping)
      setPreview(res.previewRows || [])
      setStats({ totalRows: res.totalRows, duplicates: (res.duplicates || []).length })
    } catch (e: any) {
      toast(e.message || 'Preview failed', 'error')
    } finally {
      setLoading(false)
    }
  }

  async function doCommit() {
    if (!file) return
    if (!requiredOk) { toast('Map required columns first', 'error'); return }
    setLoading(true)
    try {
      const res = await api.importCommit({ file, mapping, skipDuplicates, overwriteDuplicates, useAI, applyAICategory })
      setPreview(null)
      toast(`Imported ${res.inserted} new, updated ${res.updated}, skipped ${res.duplicatesSkipped}`, 'success')
    } catch (e: any) {
      toast(e.message || 'Import failed', 'error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Import Transactions</h2>
          <p className="page-subtitle">Upload CSV or Excel files, map columns, preview, and import.</p>
        </div>
      </div>

      <Card title="Upload File">
        <div className="row" style={{ gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <input type="file" accept=".csv,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" onChange={e => { const f = e.target.files?.[0]; if (f) onPick(f) }} />
          {file && <span className="muted">{file.name} · {(file.size/1024).toFixed(1)} KB</span>}
        </div>
      </Card>

      <Card title="Map Columns">
        <div className="col" style={{ gap: 10, maxWidth: 780 }}>
          {columns.length === 0 ? (
            <div className="muted">Pick a file to detect available columns.</div>
          ) : (
            <div className="col" style={{ gap: 12 }}>
              <div className="row" style={{ gap: 12, flexWrap: 'wrap' }}>
                <FieldSelect label="Date" value={mapping.date} onChange={v => setMapping(m => ({ ...m, date: v }))} required options={columns} />
                <FieldSelect label="Description" value={mapping.description} onChange={v => setMapping(m => ({ ...m, description: v }))} required options={columns} />
                <FieldSelect label="Amount" value={mapping.amount} onChange={v => setMapping(m => ({ ...m, amount: v }))} required options={columns} />
              </div>
              <div className="row" style={{ gap: 12, flexWrap: 'wrap' }}>
                <FieldSelect label="Type" value={mapping.type} onChange={v => setMapping(m => ({ ...m, type: v || undefined }))} options={['', ...columns]} />
                <FieldSelect label="Category" value={mapping.category} onChange={v => setMapping(m => ({ ...m, category: v || undefined }))} options={['', ...columns]} />
                <FieldSelect label="Note" value={mapping.note} onChange={v => setMapping(m => ({ ...m, note: v || undefined }))} options={['', ...columns]} />
              </div>
              <div className="row" style={{ gap: 8 }}>
                <button onClick={doPreview} disabled={!file || loading || !requiredOk}>{loading ? 'Loading…' : 'Preview'}</button>
              </div>
            </div>
          )}
        </div>
      </Card>

      {preview && (
        <Card title="Preview">
          <div className="row" style={{ gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
            <span className="chip">Rows detected: {stats?.totalRows ?? preview.length}</span>
            <span className="chip orange">Possible duplicates: {stats?.duplicates ?? 0}</span>
          </div>
          <div style={{ overflowX: 'auto', marginTop: 10 }}>
            <table className="table-rounded">
              <thead>
                <tr>
                  <th>Date</th><th>Description</th><th>Amount</th><th>Type</th><th>Category</th><th>Note</th>
                </tr>
              </thead>
              <tbody>
                {preview.slice(0, 20).map((r, i) => (
                  <tr key={i}>
                    <td>{r.date}</td>
                    <td>{r.description}</td>
                    <td>${Number(r.amount).toFixed(2)}</td>
                    <td>{r.type || '—'}</td>
                    <td>{r.category || r.categorySuggested || '—'}</td>
                    <td className="muted">{r.note || r.merchantCanonical || ''}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <Card title="Options">
        <div className="row" style={{ gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          <label className="row" style={{ gap: 6 }}>
            <input type="checkbox" checked={skipDuplicates} onChange={e => setSkipDuplicates(e.target.checked)} />
            <span>Skip duplicates</span>
          </label>
          <label className="row" style={{ gap: 6 }}>
            <input type="checkbox" checked={overwriteDuplicates} onChange={e => setOverwriteDuplicates(e.target.checked)} />
            <span>Overwrite duplicates</span>
          </label>
          <label className="row" style={{ gap: 6 }}>
            <input type="checkbox" checked={useAI} onChange={e => setUseAI(e.target.checked)} />
            <span>Use AI enrichment</span>
          </label>
          <label className="row" style={{ gap: 6 }}>
            <input type="checkbox" checked={applyAICategory} onChange={e => setApplyAICategory(e.target.checked)} />
            <span>Apply AI category when missing</span>
          </label>
          <div style={{ flex: 1 }} />
          <button onClick={doCommit} disabled={!file || !requiredOk || loading}>Import</button>
        </div>
      </Card>

      {signature && (
        <Card title="Save Preset">
          <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
            <input placeholder="Preset name (e.g., Bank of X)" value={presetName} onChange={e => setPresetName(e.target.value)} />
            <button className="btn-ghost" onClick={async () => {
              try {
                if (!presetName.trim()) { toast('Enter preset name', 'error'); return }
                await api.saveImportPreset(signature, presetName.trim(), mapping)
                toast('Preset saved', 'success')
              } catch (e: any) { toast(e.message || 'Failed to save preset', 'error') }
            }}>Save Preset</button>
          </div>
        </Card>
      )}
    </div>
  )
}

function FieldSelect({ label, value, onChange, options, required }: { label: string; value?: string; onChange: (v: string) => void; options: string[]; required?: boolean }) {
  return (
    <div className="field" style={{ minWidth: 220, flex: 1 }}>
      <label>{label}{required ? ' *' : ''}</label>
      <select value={value || ''} onChange={e => onChange(e.target.value)}>
        <option value="">—</option>
        {options.map(o => (
          <option key={o} value={o}>{o}</option>
        ))}
      </select>
    </div>
  )
}
