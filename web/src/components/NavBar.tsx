import { NavLink, useNavigate } from 'react-router-dom'
import { useEffect, useMemo, useState } from 'react'
import { auth } from '@/state/auth'
import { api } from '@/lib/api'
import { ThemeToggle } from '@/components/ThemeToggle'

export function NavBar() {
  const navigate = useNavigate()
  const session = auth.state
  const loggedIn = !!session.token
  const user = session.user
  const [month, setMonth] = useState<string>('')
  const [net, setNet] = useState<number | null>(null)
  const [budgetSpent, setBudgetSpent] = useState<number | null>(null)
  const [budgetMonthly, setBudgetMonthly] = useState<number | null>(null)

  function logout() {
    auth.clear()
    navigate('/login')
  }

  useEffect(() => {
    let stop = false
    async function load() {
      if (!loggedIn) return
      const now = new Date()
      const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0,0,0))
      const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0, 23,59,59,999))
      try {
        const [s, bs] = await Promise.all([
          api.summary({ startDate: start.toISOString(), endDate: end.toISOString() }),
          api.budgetsStatus(),
        ])
        if (stop) return
        setMonth(new Date().toISOString().slice(0,7))
        setNet(Number(s.totalIncome || 0) - Number(s.totalExpenses || 0))
        if (bs?.status) {
          const spent = bs.status.reduce((a: number, b: any) => a + Number(b.spent || 0), 0)
          const monthly = bs.status.reduce((a: number, b: any) => a + Number(b.monthly || 0), 0)
          setBudgetSpent(spent); setBudgetMonthly(monthly)
        }
      } catch {
        /* ignore */
      }
    }
    load()
    const id = setInterval(load, 60_000)
    return () => { stop = true; clearInterval(id) }
  }, [loggedIn])

  return (
    <div>
      <nav className="nav">
        <div className="row" style={{ gap: 12, alignItems: 'center' }}>
          <button className="hamburger" aria-label="Toggle navigation" onClick={() => {
            document.body.classList.toggle('show-sidebar')
          }}>
            <span />
            <span />
            <span />
          </button>
          <div className="logo" aria-label="Expense Tracker">€T</div>
        </div>
        <span style={{ flex: 1 }} />
        <div className="row" style={{ gap: 10, alignItems: 'center' }}>
          <ThemeToggle />
          <details className="user-menu">
            <summary className="user-menu-summary">
              {loggedIn ? (
                <>
                  {user?.avatarUrl ? (
                    <img className="avatar avatar-img" src={user.avatarUrl} alt="avatar" />
                  ) : (
                    <div className="avatar" aria-hidden>{(user?.name || user?.email || 'U').slice(0,1).toUpperCase()}</div>
                  )}
                  <span className="user-name-only">{user?.name || user?.email || 'Account'}</span>
                </>
              ) : (
                <>
                  <div className="avatar" aria-hidden>•</div>
                  <span className="user-name-only">Account</span>
                </>
              )}
            </summary>
            <div className="dropdown">
              {loggedIn ? (
                <>
                  <div className="dropdown-section">
                    <div className="dropdown-label">Signed in as</div>
                    <div className="dropdown-identity">{user?.name || 'Account'}</div>
                    <div className="dropdown-email">{user?.email}</div>
                  </div>
                  <NavLink to="/settings" className="dropdown-item" onClick={(e)=>{}}>
                    Settings
                  </NavLink>
                  <NavLink to="/integrations" className="dropdown-item">
                    Integrations
                  </NavLink>
                  <button className="dropdown-item" onClick={logout}>Logout</button>
                </>
              ) : (
                <>
                  <NavLink to="/login" className="dropdown-item">Login</NavLink>
                  <NavLink to="/register" className="dropdown-item">Sign up</NavLink>
                </>
              )}
            </div>
          </details>
        </div>
      </nav>
      {loggedIn && net !== null && budgetSpent !== null && budgetMonthly !== null && (
        <div className="subnav">
          <div className="chip blue">{month}</div>
          <div className="chip" style={{ color: net >= 0 ? '#7ee787' : '#ff6b6b' }}>Net ${net.toFixed(2)}</div>
          <div className="chip">Budgets ${budgetSpent.toFixed(0)} / ${budgetMonthly.toFixed(0)}</div>
        </div>
      )}
    </div>
  )
}
