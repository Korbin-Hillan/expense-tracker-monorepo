import { useEffect, useMemo, useState } from 'react'
import { Modal, TextInput, Select, Textarea, Button, Group, SegmentedControl } from '@mantine/core'
import { api, type Transaction } from '@/lib/api'

type Props = {
  opened: boolean
  onClose: () => void
  tx: Transaction | null
  onSaved?: () => void
}

const EXPENSE_CATEGORIES = ['Food','Transportation','Shopping','Bills','Entertainment','Health','Other']
const INCOME_CATEGORIES = ['Salary','Bonus','Interest','Investment','Refunds','Gifts','Other Income']

export function EditTransactionModal({ opened, onClose, tx, onSaved }: Props) {
  const [type, setType] = useState<'expense' | 'income'>('expense')
  const [amount, setAmount] = useState<string>('')
  const [category, setCategory] = useState<string>('')
  const [date, setDate] = useState<string>('')
  const [note, setNote] = useState<string>('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!tx) return
    setType(tx.type)
    setAmount(String(Math.abs(Number(tx.amount ?? 0))))
    setCategory(tx.category || '')
    const d = new Date(tx.date)
    setDate(!isNaN(d.getTime()) ? d.toISOString().slice(0,10) : new Date().toISOString().slice(0,10))
    setNote(tx.note || '')
    setError(null)
  }, [tx])

  const allowed = useMemo(() => (type === 'income' ? INCOME_CATEGORIES : EXPENSE_CATEGORIES), [type])
  const categoryOptions = useMemo(() => {
    // Ensure current category stays selectable even if not in presets
    const opts = allowed.map(c => ({ value: c, label: c }))
    if (category && !allowed.includes(category)) {
      opts.push({ value: category, label: `${category} (custom)` })
    }
    return opts
  }, [allowed, category])

  useEffect(() => {
    // If switching type and current category not allowed, clear it to force selection
    if (category && !allowed.includes(category)) {
      setCategory('')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type])

  async function submit() {
    if (!tx) return
    setError(null)
    const amt = parseFloat(amount)
    if (!Number.isFinite(amt) || amt <= 0) { setError('Enter a valid amount'); return }
    if (!category) { setError('Choose a category'); return }
    try {
      setSaving(true)
      await api.updateTransaction(tx.id, {
        type,
        amount: amt,
        category,
        note: note || null,
        date: new Date(date + 'T12:00:00').toISOString(),
      })
      onSaved?.()
      onClose()
    } catch (e: any) {
      setError(e?.message || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal opened={opened} onClose={onClose} title="Edit Transaction" centered>
      <div className="col" style={{ gap: 12 }}>
        <SegmentedControl
          data={[{ label: 'Expense', value: 'expense' }, { label: 'Income', value: 'income' }]}
          value={type}
          onChange={(v)=>setType(v as 'expense'|'income')}
        />
        <TextInput label="Amount" placeholder="0.00" value={amount} onChange={(e)=>setAmount(e.currentTarget.value)} type="number" step="0.01" min={0} required />
        <Select label="Category" placeholder={type === 'income' ? 'Income category' : 'Expense category'} data={categoryOptions} value={category} onChange={(v)=>setCategory(v || '')} searchable required />
        <TextInput label="Date" type="date" value={date} onChange={(e)=>setDate(e.currentTarget.value)} required />
        <Textarea label="Note" placeholder="Optional" autosize minRows={2} value={note} onChange={(e)=>setNote(e.currentTarget.value)} />
        {error && <div style={{ color: 'var(--danger)', fontSize: 13 }}>{error}</div>}
        <Group justify="flex-end" mt="sm">
          <Button variant="default" onClick={onClose} disabled={saving}>Cancel</Button>
          <Button onClick={submit} loading={saving}>Save</Button>
        </Group>
      </div>
    </Modal>
  )
}
