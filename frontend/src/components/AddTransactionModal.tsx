import { useMemo, useState } from 'react'
import { Modal, TextInput, Select, Textarea, Button, Group } from '@mantine/core'
import { api } from '@/lib/api'

type Props = {
  opened: boolean
  onClose: () => void
  type: 'expense' | 'income'
  onAdded?: () => void
}

const EXPENSE_CATEGORIES = ['Food','Transportation','Shopping','Bills','Entertainment','Health','Other']
const INCOME_CATEGORIES = ['Salary','Bonus','Interest','Investment','Refunds','Gifts','Other Income']

export function AddTransactionModal({ opened, onClose, type, onAdded }: Props) {
  const [amount, setAmount] = useState<string>('')
  const [category, setCategory] = useState<string>('')
  const [date, setDate] = useState<string>(() => new Date().toISOString().slice(0,10))
  const [note, setNote] = useState<string>('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const categoryOptions = useMemo(() => {
    const base = type === 'income' ? INCOME_CATEGORIES : EXPENSE_CATEGORIES
    return base.map(c => ({ value: c, label: c }))
  }, [type])

  function reset() {
    setAmount('')
    setCategory('')
    setDate(new Date().toISOString().slice(0,10))
    setNote('')
    setError(null)
  }

  async function submit() {
    setError(null)
    const amt = parseFloat(amount)
    if (!Number.isFinite(amt) || amt <= 0) { setError('Enter a valid amount'); return }
    if (!category) { setError('Choose a category'); return }
    try {
      setSaving(true)
      await api.addTransaction({
        type,
        amount: amt,
        category,
        note: note || null,
        date: new Date(date + 'T12:00:00').toISOString(),
      })
      reset()
      onClose()
      onAdded?.()
    } catch (e: any) {
      setError(e?.message || 'Failed to add')
    } finally {
      setSaving(false)
    }
  }

  const title = type === 'expense' ? 'Add Expense' : 'Add Income'

  return (
    <Modal opened={opened} onClose={() => { reset(); onClose() }} title={title} centered>
      <div className="col" style={{ gap: 12 }}>
        <TextInput label="Amount" placeholder="0.00" value={amount} onChange={(e)=>setAmount(e.currentTarget.value)} type="number" step="0.01" min={0} required />
        <Select label="Category" placeholder={type === 'income' ? 'Income category' : 'Expense category'} data={categoryOptions} value={category} onChange={(v)=>setCategory(v || '')} searchable required />
        <TextInput label="Date" type="date" value={date} onChange={(e)=>setDate(e.currentTarget.value)} required />
        <Textarea label="Note" placeholder="Optional" autosize minRows={2} value={note} onChange={(e)=>setNote(e.currentTarget.value)} />
        {error && <div style={{ color: 'var(--danger)', fontSize: 13 }}>{error}</div>}
        <Group justify="flex-end" mt="sm">
          <Button variant="default" onClick={() => { reset(); onClose() }} disabled={saving}>Cancel</Button>
          <Button onClick={submit} loading={saving}>{title}</Button>
        </Group>
      </div>
    </Modal>
  )
}
