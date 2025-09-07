import { useEffect, useMemo, useState } from 'react'
import { api, ApiUser } from '@/lib/api'
import { auth } from '@/state/auth'
import { Card } from '@/components/UI'
import { toast } from '@/lib/toast'

function getTimezones(): string[] {
  const sys = (Intl as any)?.supportedValuesOf?.('timeZone') as string[] | undefined
  if (Array.isArray(sys) && sys.length) return sys
  return [
    'UTC', 'America/Los_Angeles', 'America/New_York', 'America/Chicago', 'America/Denver',
    'Europe/London', 'Europe/Berlin', 'Europe/Paris', 'Europe/Madrid', 'Europe/Rome',
    'Asia/Tokyo', 'Asia/Seoul', 'Asia/Shanghai', 'Asia/Singapore', 'Asia/Kolkata',
    'Australia/Sydney'
  ]
}

export function Settings() {
  const [user, setUser] = useState<ApiUser | null>(auth.state.user)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [name, setName] = useState(user?.name || '')
  const [timezone, setTimezone] = useState(user?.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone)
  const [newPassword, setNewPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [currentPassword, setCurrentPassword] = useState('')
  const passwordStrength = useMemo(() => {
    const pw = newPassword || ''
    const length = pw.length >= 8 ? 1 : 0
    const mix = ([/[a-z]/, /[A-Z]/, /\d/, /[^\w\s]/].filter(r => r.test(pw)).length >= 3) ? 1 : 0
    return length + mix // 0..2
  }, [newPassword])
  const [newEmail, setNewEmail] = useState(user?.email || '')
  const [emailToken, setEmailToken] = useState('')
  const [avatarDataUrl, setAvatarDataUrl] = useState<string | null>(null)

  useEffect(() => {
    let mounted = true
    async function loadMe() {
      try {
        setLoading(true)
        const me = await api.me()
        if (!mounted) return
        setUser(me.user)
        setName(me.user.name || '')
        setTimezone(me.user.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone)
        auth.setUser(me.user)
      } finally {
        if (mounted) setLoading(false)
      }
    }
    loadMe()
    // Optional: pick up token from URL
    try {
      const u = new URL(window.location.href)
      const t = u.searchParams.get('email_token')
      if (t) setEmailToken(t)
    } catch {}
    return () => { mounted = false }
  }, [])

  async function saveProfile() {
    try {
      setSaving(true)
      const res = await api.updateProfile({ name, timezone })
      setUser(res.user)
      auth.setUser(res.user)
      toast('Profile updated', 'success')
    } catch (e: any) {
      toast(e.message || 'Failed to update profile', 'error')
    } finally {
      setSaving(false)
    }
  }

  async function saveTimezone() {
    try {
      await api.updateTimezone(timezone)
      const me = await api.me()
      setUser(me.user)
      auth.setUser(me.user)
      toast('Timezone saved', 'success')
    } catch (e: any) {
      toast(e.message || 'Failed to save timezone', 'error')
    }
  }

  async function changePassword() {
    try {
      if (!currentPassword) { toast('Enter your current password', 'error'); return }
      if (!newPassword || newPassword.length < 6) { toast('Password too short', 'error'); return }
      if (newPassword !== confirm) { toast('Passwords do not match', 'error'); return }
      await api.updatePassword(currentPassword, newPassword)
      setCurrentPassword(''); setNewPassword(''); setConfirm('')
      toast('Password updated', 'success')
    } catch (e: any) {
      toast(e.message || 'Failed to update password', 'error')
    }
  }

  async function deleteAccount() {
    try {
      const ok = window.confirm('Delete your account and all data? This cannot be undone.')
      if (!ok) return
      await api.deleteAccount()
      auth.clear()
      window.location.href = '/login'
    } catch (e: any) {
      toast(e.message || 'Failed to delete account', 'error')
    }
  }

  const isPassword = (user?.provider || 'password') === 'password'
  const tzs = useMemo(getTimezones, [])

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Settings</h2>
          <p className="page-subtitle">Manage your profile, preferences, and account.</p>
        </div>
      </div>

      <Card title="Profile">
        {loading ? <div>Loading…</div> : (
          <div className="col" style={{ gap: 12, maxWidth: 520 }}>
            <div className="row" style={{ gap: 12, alignItems: 'center' }}>
              {user?.avatarUrl || avatarDataUrl ? (
                <img className="avatar avatar-img" src={avatarDataUrl || user?.avatarUrl || ''} alt="avatar" style={{ width: 48, height: 48 }} />
              ) : (
                <div className="avatar" style={{ width: 48, height: 48, fontSize: 18 }} aria-hidden>{(user?.name || user?.email || 'U').slice(0,1).toUpperCase()}</div>
              )}
              <div className="col" style={{ gap: 6 }}>
                <input type="file" accept="image/png,image/jpeg,image/webp" onChange={e => {
                  const f = e.target.files?.[0]
                  if (!f) return
                  if (f.size > 512 * 1024) { toast('Max 512KB image', 'error'); return }
                  const r = new FileReader()
                  r.onload = () => setAvatarDataUrl(String(r.result || ''))
                  r.readAsDataURL(f)
                }} />
                <div className="row" style={{ gap: 8 }}>
                  <button className="btn-ghost" onClick={async () => { if (!avatarDataUrl) { toast('Choose an image first', 'info'); return } const res = await api.updateAvatar(avatarDataUrl); setUser(res.user); auth.setUser(res.user); setAvatarDataUrl(null); toast('Avatar updated', 'success') }}>Save Avatar</button>
                  {avatarDataUrl && <button className="btn-ghost" onClick={() => setAvatarDataUrl(null)}>Cancel</button>}
                </div>
              </div>
            </div>
            <div className="field">
              <label>Name</label>
              <input value={name} onChange={e => setName(e.target.value)} placeholder="Your name" />
            </div>
            <div className="field">
              <label>Email</label>
              <input value={user?.email || ''} disabled />
            </div>
            <div className="row" style={{ gap: 8 }}>
              <button onClick={saveProfile} disabled={saving}>{saving ? 'Saving…' : 'Save Profile'}</button>
              <span className="muted">Provider: {user?.provider || '—'}</span>
            </div>
          </div>
        )}
      </Card>

      {user?.provider === 'password' && (
        <Card title="Email">
          <div className="col" style={{ gap: 10, maxWidth: 520 }}>
            <div className="field">
              <label>New Email</label>
              <input type="email" value={newEmail} onChange={e => setNewEmail(e.target.value)} placeholder="you@example.com" />
            </div>
            <div className="field">
              <label>Current Password</label>
              <input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} placeholder="••••••••" />
            </div>
            <div>
              <button onClick={async () => { try { if (!currentPassword) { toast('Enter your current password', 'error'); return } await api.requestEmailChange(newEmail, currentPassword); toast('Verification link sent (check server logs in dev)', 'success') } catch (e: any) { toast(e.message || 'Failed to start email change', 'error') } }}>Send Verification</button>
            </div>
            <div className="row" style={{ gap: 8, alignItems: 'center' }}>
              <input placeholder="Paste verification token" value={emailToken} onChange={e => setEmailToken(e.target.value)} />
              <button className="btn-ghost" onClick={async () => { try { await api.verifyEmailToken(emailToken); const me = await api.me(); setUser(me.user); auth.setUser(me.user); setEmailToken(''); toast('Email verified and updated', 'success') } catch (e: any) { toast(e.message || 'Failed to verify token', 'error') } }}>Verify Token</button>
            </div>
          </div>
        </Card>
      )}

      <Card title="Preferences">
        <div className="col" style={{ gap: 10, maxWidth: 520 }}>
          <div className="field">
            <label>Timezone</label>
            <select value={timezone} onChange={e => setTimezone(e.target.value)}>
              {tzs.map(tz => <option key={tz} value={tz}>{tz}</option>)}
            </select>
          </div>
          <div>
            <button onClick={saveTimezone}>Save Timezone</button>
          </div>
        </div>
      </Card>

      {isPassword && (
        <Card title="Security">
          <div className="col" style={{ gap: 10, maxWidth: 520 }}>
            <div className="field">
              <label>Current Password</label>
              <input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} placeholder="••••••••" />
            </div>
            <div className="field">
              <label>New Password</label>
              <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} placeholder="••••••••" />
              <div className="progress" aria-label="Password strength" style={{ marginTop: 6 }}>
                <div className="progress-fill" style={{ width: `${(passwordStrength/2)*100}%`, background: passwordStrength >= 2 ? 'linear-gradient(90deg,#2ea043,#86efac)' : passwordStrength === 1 ? 'linear-gradient(90deg,#f59e0b,#fde047)' : 'linear-gradient(90deg,#ef4444,#f97316)' }} />
              </div>
              <div className="muted" style={{ fontSize: 12 }}>Use at least 8 chars and mix cases/digits/symbols.</div>
            </div>
            <div className="field">
              <label>Confirm Password</label>
              <input type="password" value={confirm} onChange={e => setConfirm(e.target.value)} placeholder="••••••••" />
            </div>
            <div>
              <button onClick={changePassword}>Update Password</button>
            </div>
          </div>
        </Card>
      )}

      <Card title="Danger Zone">
        <div className="row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
          <div className="col" style={{ gap: 4 }}>
            <strong>Delete Account</strong>
            <span className="muted">Permanently remove your account and all data.</span>
          </div>
          <button className="btn-ghost" onClick={deleteAccount} style={{ borderColor: 'rgba(255,107,107,0.4)', color: 'var(--danger)' }}>Delete</button>
        </div>
      </Card>
    </div>
  )
}
