import { FormEvent, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { api } from '@/lib/api'
import { auth } from '@/state/auth'
import { GoogleSignInButton, AppleSignInButton } from '@/components/SocialAuth'

export function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const res = await api.login(email, password)
      auth.setSession(res)
      navigate('/dashboard')
    } catch (e: any) {
      setError(e.message || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-grid container">
      <section className="auth-hero">
        <h1 className="hero-title">Welcome back</h1>
        <p className="hero-subtitle">Track spending, plan budgets, and get AI insights to stay on top of your money.</p>
        <ul className="hero-bullets">
          <li>Clear dashboards and monthly summaries</li>
          <li>Smart budgets with progress</li>
          <li>AI insights and alerts</li>
        </ul>
      </section>
      <div className="card auth-card">
        <h2>Sign in</h2>
        <form className="form" onSubmit={onSubmit}>
          <div className="field">
            <label>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required placeholder="you@example.com" />
          </div>
          <div className="field">
            <label>Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} required placeholder="••••••••" />
          </div>
          {error && <div className="form-error">{error}</div>}
          <button type="submit" disabled={loading}>{loading ? 'Logging in…' : 'Login'}</button>
        </form>
        <div className="divider"><span>or</span></div>
        <div className="row" style={{ gap: 8, marginTop: 4, justifyContent: 'center' }}>
          <GoogleSignInButton />
          <AppleSignInButton />
        </div>
        <p className="muted" style={{ marginTop: 12 }}>No account? <Link to="/register">Create one</Link></p>
      </div>
    </div>
  )
}
