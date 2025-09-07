import { Router } from 'express'
import { ObjectId } from 'mongodb'
import { requireAppJWT } from '../middleware/auth.ts'
import { transactionsCollection } from '../database/transactions.ts'
import { recurringExpensesCollection } from '../database/recurringExpenses.ts'

export const calendarRouter = Router()

function icsEscape(s: string) {
  return String(s || '').replace(/\\/g,'\\\\').replace(/;/g,'\;').replace(/,/g,'\,').replace(/\n/g,'\\n')
}

function toDate(d: Date) {
  const y = d.getUTCFullYear(); const m = String(d.getUTCMonth()+1).padStart(2,'0'); const day = String(d.getUTCDate()).padStart(2,'0')
  return `${y}${m}${day}`
}

calendarRouter.get('/api/calendar/ics', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId))
    const recCol = await recurringExpensesCollection()
    const list = await recCol.find({ userId, isActive: true }).toArray()

    // Build next 90 days events, naive monthly/weekly recurrence by next 3 occurrences
    const now = new Date()
    const until = new Date(now.getTime() + 90*86400000)
    let ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//ExpenseTracker//Calendar//EN\n'
    for (const r of list) {
      const title = `${r.name} (${r.category})`
      // Guess next due from lastSeen + frequency
      let gapDays = r.frequency === 'weekly' ? 7 : r.frequency === 'biweekly' ? 14 : r.frequency === 'yearly' ? 365 : 30
      let next = new Date(r.lastSeen || new Date())
      next.setDate(next.getDate() + gapDays)
      while (next <= until) {
        const uid = `${r._id}-${next.getTime()}@expense-tracker`
        const dt = `${toDate(next)}T090000Z`
        const amount = r.averageAmount?.toFixed(2) || ''
        const desc = `Estimated bill: $${amount}`
        ics += `BEGIN:VEVENT\nUID:${uid}\nDTSTAMP:${toDate(now)}T000000Z\nDTSTART:${dt}\nSUMMARY:${icsEscape(title)}\nDESCRIPTION:${icsEscape(desc)}\nEND:VEVENT\n`
        next = new Date(next.getTime() + gapDays*86400000)
      }
    }
    ics += 'END:VCALENDAR\n'
    res.setHeader('Content-Type','text/calendar')
    res.setHeader('Content-Disposition','attachment; filename="bills.ics"')
    res.send(ics)
  } catch (e) {
    res.status(500).json({ error: 'ics_failed' })
  }
})

