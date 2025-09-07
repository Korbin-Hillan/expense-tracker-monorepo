import { useEffect, useState } from 'react'
import { api } from '@/lib/api'
import { Card } from '@/components/UI'
import { toast } from '@/lib/toast'

type Integration = { provider: string; extra?: any; updatedAt?: string }

export function IntegrationsPage() {
  const [items, setItems] = useState<Integration[]>([])
  const [plaidToken, setPlaidToken] = useState<string | null>(null)

  async function load() {
    const res = await api.listIntegrations()
    setItems(res.integrations || [])
  }
  useEffect(() => { load() }, [])

  async function connectPlaid() {
    try {
      const t = await api.createPlaidLinkToken()
      setPlaidToken(t.link_token || '')
      toast('Plaid link token created (mock)', 'info')
      // In production: open Plaid Link with the token and call api.exchangePlaidPublicToken
    } catch (e: any) { toast(e.message || 'Plaid init failed', 'error') }
  }

  async function disconnect(provider: string) {
    await api.disconnectIntegration(provider)
    await load()
  }

  async function downloadICS() {
    const url = `${import.meta.env.VITE_API_BASE_URL || ''}/api/calendar/ics`
    const a = document.createElement('a')
    a.href = url
    a.download = 'bills.ics'
    a.click()
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <div className="page-header">
        <div>
          <h2 className="page-title">Integrations</h2>
          <p className="page-subtitle">Connect banks, email, calendar, and export targets.</p>
        </div>
      </div>

      <Card title="Banks (Plaid)">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button onClick={connectPlaid}>Connect Plaid (stub)</button>
          <button className="btn-ghost" onClick={() => disconnect('plaid')}>Disconnect</button>
        </div>
        {items.find(i => i.provider === 'plaid') && <div className="muted" style={{ marginTop: 8 }}>Connected</div>}
      </Card>

      <Card title="Email Inbox Import (Gmail)">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button className="btn-ghost" onClick={() => toast('Gmail OAuth URL is returned from /api/integrations/google/oauth-url (stub)', 'info')}>Connect Gmail (stub)</button>
          <button className="btn-ghost" onClick={() => disconnect('google')}>Disconnect</button>
        </div>
      </Card>

      <Card title="Calendar">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button onClick={downloadICS}>Download Upcoming Bills (.ics)</button>
        </div>
      </Card>

      <Card title="Exports (Sheets / Notion)">
        <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button className="btn-ghost" onClick={() => toast('Google Sheets export stub — configure tokens server-side', 'info')}>Export to Google Sheets</button>
          <button className="btn-ghost" onClick={() => toast('Notion export stub — configure token + DB id', 'info')}>Export to Notion</button>
        </div>
      </Card>
    </div>
  )
}

