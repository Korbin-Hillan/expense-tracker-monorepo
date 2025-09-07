import { useEffect, useState } from 'react'
import { api } from '@/lib/api'
import { Card, ProgressBar, StatGrid, StatCard, BarChart } from '@/components/UI'

type Insight = { id: string; title: string; description: string; category: string; confidence: number; actionable?: boolean }

export function Insights() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [insights, setInsights] = useState<Insight[]>([])
  const [narrative, setNarrative] = useState<string>('')
  const [digestLoading, setDigestLoading] = useState(false)
  const [digest, setDigest] = useState<string>('')
  const [health, setHealth] = useState<any | null>(null)
  const [alerts, setAlerts] = useState<any[]>([])
  const [confidenceData, setConfidenceData] = useState<{ label: string; value: number }[]>([])

  async function loadInsights() {
    setLoading(true)
    setError(null)
    try {
      const payload = await api.gptInsights()
      setInsights(payload.insights || [])
      setNarrative(payload.narrative || '')
      if (payload.insights) {
        // Bucket confidences into 10% bins
        const buckets = new Array(10).fill(0)
        for (const i of payload.insights) {
          const idx = Math.min(9, Math.floor((i.confidence || 0) * 10))
          buckets[idx]++
        }
        setConfidenceData(buckets.map((n, idx) => ({ label: `${idx*10}-${idx*10+10}%`, value: n })))
      }
    } catch (e: any) {
      setError(e.message || 'Failed to load insights')
    } finally {
      setLoading(false)
    }
  }

  async function loadHealthAlerts() {
    try {
      const [hs, al] = await Promise.all([api.healthScore().catch(() => null), api.alerts().catch(() => ({ alerts: [] }))])
      setHealth(hs)
      setAlerts(al?.alerts || [])
    } catch {
      /* ignore */
    }
  }

  useEffect(() => {
    loadInsights()
    loadHealthAlerts()
  }, [])

  async function fetchDigest() {
    setDigestLoading(true)
    try {
      const d = await api.weeklyDigest()
      setDigest(d.digest)
    } finally {
      setDigestLoading(false)
    }
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Insights</h2>

      <Card
        title={<span>AI Insights</span>}
        actions={
          <div className="row" style={{ gap: 8 }}>
            <button onClick={loadInsights} disabled={loading}>{loading ? 'Loading…' : 'Generate GPT Insights'}</button>
            <button className="btn-ghost" onClick={fetchDigest} disabled={digestLoading}>{digestLoading ? 'Generating…' : 'Weekly Digest'}</button>
          </div>
        }
      >
        {error && <div>{error}</div>}
        {narrative && (
          <div className="col" style={{ gap: 6, marginBottom: 12 }}>
            <div className="chip purple">Forecast Narrative</div>
            <p className="muted" style={{ whiteSpace: 'pre-wrap' }}>{narrative}</p>
          </div>
        )}
        {digest && (
          <div className="col" style={{ gap: 6 }}>
            <div className="chip blue">Weekly Digest</div>
            <p className="muted" style={{ whiteSpace: 'pre-wrap' }}>{digest}</p>
          </div>
        )}
        {insights.length > 0 && (
          <div className="col" style={{ gap: 10, marginTop: 12 }}>
            {insights.map(i => (
              <div key={i.id} className="stat-card" style={{ padding: 12 }}>
                <div className="row" style={{ justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <strong>{i.title}</strong>
                  <span className="chip green">{Math.round(i.confidence * 100)}%</span>
                </div>
                <div className="muted" style={{ marginTop: 6 }}>{i.description}</div>
                <div style={{ marginTop: 8 }}><span className="chip orange">{i.category}</span>{i.actionable ? <span style={{ marginLeft: 8 }} className="chip green">Actionable</span> : null}</div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {confidenceData.length > 0 && (
        <Card title="Confidence Distribution">
          <BarChart data={confidenceData} />
        </Card>
      )}

      {health && (
        <Card title="Financial Health">
          <StatGrid>
            <StatCard label="Score" value={<span>{health.score}/100</span>} />
          </StatGrid>
          {Array.isArray(health.components) && (
            <div className="col" style={{ marginTop: 8, gap: 10 }}>
              {health.components.map((c: any) => (
                <div key={c.key} className="col" style={{ gap: 4 }}>
                  <div className="row" style={{ justifyContent: 'space-between' }}>
                    <span>{c.label}</span>
                    <span className="muted">{c.score}/{c.max}</span>
                  </div>
                  <ProgressBar value={Number(c.score)} max={Number(c.max)} />
                </div>
              ))}
            </div>
          )}
        </Card>
      )}

      {alerts.length > 0 && (
        <Card title="Alerts">
          <div className="col" style={{ gap: 8 }}>
            {alerts.map((a: any) => (
              <div key={a.id} className="row" style={{ justifyContent: 'space-between' }}>
                <div className="col" style={{ gap: 4 }}>
                  <div><span className="chip orange" style={{ marginRight: 8 }}>ALERT</span><strong>{a.title}</strong></div>
                  <div className="muted">{a.description}</div>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}
    </div>
  )
}
