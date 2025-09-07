import { Router } from 'express'
import { ObjectId } from 'mongodb'
import { requireAppJWT } from '../middleware/auth.ts'
import { integrationsCollection } from '../database/integrations.ts'
import { transactionsCollection } from '../database/transactions.ts'

export const integrationsRouter = Router()

// List connected integrations
integrationsRouter.get('/api/integrations', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const col = await integrationsCollection()
  const list = await col.find({ userId }).project({ accessToken: 0, refreshToken: 0 }).toArray()
  res.json({ integrations: list })
})

integrationsRouter.post('/api/integrations/disconnect', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const provider = String(req.body?.provider || '') as any
  const col = await integrationsCollection()
  await col.deleteOne({ userId, provider })
  res.json({ success: true })
})

// ---- Plaid stubs ----
integrationsRouter.post('/api/integrations/plaid/link-token', requireAppJWT as any, async (req, res) => {
  // In production: create link token via Plaid SDK using PLAID_CLIENT_ID/SECRET
  if (!process.env.PLAID_CLIENT_ID || !process.env.PLAID_SECRET) {
    res.json({ link_token: 'mock-link-token', sandbox: true })
    return
  }
  // Placeholder for real call; avoid network in this environment
  res.json({ link_token: 'unavailable_in_this_env' })
})

integrationsRouter.post('/api/integrations/plaid/exchange', requireAppJWT as any, async (req, res) => {
  const userId = new ObjectId(String((req as any).userId))
  const publicToken = String(req.body?.public_token || '')
  if (!publicToken) { res.status(400).json({ error: 'missing_public_token' }); return }
  const col = await integrationsCollection()
  // In production: exchange public_token -> access_token via Plaid
  const doc = { userId, provider: 'plaid', accessToken: `mock-${publicToken}`, createdAt: new Date(), updatedAt: new Date() } as any
  await col.updateOne({ userId, provider: 'plaid' as any }, { $set: doc }, { upsert: true })
  res.json({ success: true })
})

// Webhook endpoint (stub)
integrationsRouter.post('/api/integrations/plaid/webhook', async (req, res) => {
  console.log('Plaid webhook (stub):', req.body)
  res.json({ ok: true })
})

// ---- Google OAuth (Gmail/Calendar/Sheets) stubs ----
function buildGoogleOAuthURL(scopes: string[], redirectUri: string) {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID
  const base = 'https://accounts.google.com/o/oauth2/v2/auth'
  const params = new URLSearchParams({
    client_id: String(clientId || 'your-google-client-id'),
    redirect_uri: redirectUri,
    response_type: 'code',
    access_type: 'offline',
    prompt: 'consent',
    scope: scopes.join(' '),
  })
  return `${base}?${params.toString()}`
}

integrationsRouter.get('/api/integrations/google/oauth-url', requireAppJWT as any, async (req, res) => {
  const redirectUri = String(req.query.redirect_uri || process.env.GOOGLE_OAUTH_REDIRECT_URI || 'http://localhost:3000/api/integrations/google/callback')
  const type = String(req.query.type || 'gmail') // gmail|calendar|sheets
  const scopes = type === 'calendar'
    ? ['https://www.googleapis.com/auth/calendar']
    : type === 'sheets'
      ? ['https://www.googleapis.com/auth/spreadsheets']
      : ['https://www.googleapis.com/auth/gmail.readonly']
  res.json({ url: buildGoogleOAuthURL(scopes, redirectUri) })
})

integrationsRouter.get('/api/integrations/google/callback', async (req, res) => {
  // In production: exchange code for tokens, persist in integrations collection.
  res.send('Google OAuth callback (stub). Exchange code for tokens on server and store in DB.')
})

// ---- Exports stubs ----
integrationsRouter.post('/api/export/google-sheets', requireAppJWT as any, async (req, res) => {
  // In production: use Google Sheets API with stored tokens to write rows.
  res.json({ success: false, error: 'not_configured' })
})

integrationsRouter.post('/api/export/notion', requireAppJWT as any, async (req, res) => {
  // In production: use Notion API (token+database id) to sync latest transactions.
  res.json({ success: false, error: 'not_configured' })
})

