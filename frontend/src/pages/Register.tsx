import { FormEvent, useMemo, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { api } from '@/lib/api'
import { auth } from '@/state/auth'
import { GoogleSignInButton, AppleSignInButton } from '@/components/SocialAuth'

export function Register() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const strength = useMemo(() => {
    const pw = password || ''
    const length = pw.length >= 8 ? 1 : 0
    const mix = ([/[a-z]/, /[A-Z]/, /\d/, /[^\w\s]/].filter(r => r.test(pw)).length >= 3) ? 1 : 0
    return length + mix // 0..2
  }, [password])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const res = await api.register(email, password, name)
      auth.setSession(res)
      navigate('/dashboard')
    } catch (e: any) {
      setError(e.message || 'Registration failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-grid container">
      <section className="auth-hero">
        <h1 className="hero-title">Create your account</h1>
        <p className="hero-subtitle">Get started with a modern, delightful expense tracker.</p>
        <ul className="hero-bullets">
          <li>Fast imports and clean editing</li>
          <li>Budgets, summaries, exports</li>
          <li>Helpful AI guidance</li>
        </ul>
      </section>
      <div className="card auth-card">
        <h2>Register</h2>
        <form className="form" onSubmit={onSubmit}>
          <div className="field">
            <label>Name</label>
            <input value={name} onChange={e => setName(e.target.value)} placeholder="Jane Doe" />
          </div>
          <div className="field">
            <label>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required placeholder="you@example.com" />
          </div>
          <div className="field">
            <label>Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} required placeholder="••••••••" />
            <div className="progress" aria-label="Password strength" style={{ marginTop: 6 }}>
              <div className="progress-fill" style={{ width: `${(strength/2)*100}%`, background: strength >= 2 ? 'linear-gradient(90deg,#2ea043,#86efac)' : strength === 1 ? 'linear-gradient(90deg,#f59e0b,#fde047)' : 'linear-gradient(90deg,#ef4444,#f97316)' }} />
            </div>
            <div className="muted" style={{ fontSize: 12 }}>Use at least 8 chars and mix cases/digits/symbols.</div>
          </div>
          {error && <div className="form-error">{error}</div>}
          <button type="submit" disabled={loading}>{loading ? 'Creating…' : 'Create account'}</button>
        </form>
        <div className="divider"><span>or</span></div>
        <div className="row" style={{ gap: 8, marginTop: 4, justifyContent: 'center' }}>
          <GoogleSignInButton />
          <AppleSignInButton />
        </div>
        <p className="muted" style={{ marginTop: 12, textAlign: 'center' }}>Have an account? <Link to="/login">Login</Link></p>
      </div>
    </div>
  )
}
