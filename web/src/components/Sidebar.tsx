import { NavLink } from 'react-router-dom'

export function Sidebar() {
  return (
    <aside className="sidebar" role="navigation" aria-label="Primary">
      <div className="sidebar-inner">
        <Section title="Overview">
          <Item to="/dashboard" label="Dashboard" />
        </Section>
        <Section title="Money">
          <Item to="/transactions" label="Transactions" />
          <Item to="/budgets" label="Budgets" />
          <Item to="/subscriptions" label="Subscriptions" />
          <Item to="/recurring" label="Recurring" />
        </Section>
        <Section title="Insights">
          <Item to="/insights" label="Insights" />
          <Item to="/chat" label="Chat" />
        </Section>
        <Section title="Tools">
          <Item to="/import" label="Import" />
          <Item to="/rules" label="Rules" />
          <Item to="/duplicates" label="Duplicates" />
        </Section>
        <Section title="Integrations">
          <Item to="/integrations" label="Integrations" />
        </Section>
      </div>
    </aside>
  )
}

function Section({ title, children }: { title: string; children: any }) {
  return (
    <div className="sidebar-section">
      <div className="sidebar-section-title">{title}</div>
      <div className="sidebar-items">{children}</div>
    </div>
  )
}

function Item({ to, label }: { to: string; label: string }) {
  return (
    <NavLink to={to} className={({ isActive }) => `sidebar-item${isActive ? ' active' : ''}`}>
      <span className="sidebar-item-label">{label}</span>
    </NavLink>
  )
}

