import { ReactNode } from 'react'

export function Card({ title, actions, children }: { title?: ReactNode; actions?: ReactNode; children: ReactNode }) {
  return (
    <div className="card">
      {(title || actions) && (
        <div className="card-head">
          {title && <div className="card-title">{title}</div>}
          <div style={{ flex: 1 }} />
          {actions}
        </div>
      )}
      <div className="card-body">{children}</div>
    </div>
  )
}

export function StatGrid({ children }: { children: ReactNode }) {
  return <div className="stat-grid">{children}</div>
}

export function StatCard({ label, value, hint }: { label: string; value: ReactNode; hint?: ReactNode }) {
  return (
    <div className="stat-card">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {hint && <div className="stat-hint">{hint}</div>}
    </div>
  )
}

export function ProgressBar({ value, max }: { value: number; max: number }) {
  const pct = Math.max(0, Math.min(100, max > 0 ? (value / max) * 100 : 0))
  return (
    <div className="progress">
      <div className="progress-fill" style={{ width: `${pct}%` }} />
    </div>
  )
}

export function BarChart({ data }: { data: { label: string; value: number }[] }) {
  const max = Math.max(1, ...data.map(d => d.value))
  return (
    <div className="barchart">
      {data.map((d) => (
        <div key={d.label} className="bar-row">
          <div className="bar-label">{d.label}</div>
          <div className="bar-track">
            <div className="bar-fill" style={{ width: `${(d.value / max) * 100}%` }} />
          </div>
          <div className="bar-value">${d.value.toFixed(0)}</div>
        </div>
      ))}
    </div>
  )
}

export function TrendChart({ data }: { data: { label: string; income: number; expenses: number }[] }) {
  const max = Math.max(1, ...data.map(d => Math.max(d.income, d.expenses)))
  return (
    <div className="trendchart">
      {data.map(d => (
        <div key={d.label} className="trend-col">
          <div className="bars">
            <div className="bar income" style={{ height: `${(d.income / max) * 100}%` }} title={`Income $${d.income.toFixed(2)}`} />
            <div className="bar expense" style={{ height: `${(d.expenses / max) * 100}%` }} title={`Expenses $${d.expenses.toFixed(2)}`} />
          </div>
          <div className="trend-label">{d.label}</div>
        </div>
      ))}
    </div>
  )
}
