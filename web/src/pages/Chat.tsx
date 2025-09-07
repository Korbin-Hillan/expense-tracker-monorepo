import { FormEvent, useRef, useState } from 'react'
import { api } from '@/lib/api'
import { Card } from '@/components/UI'

type Msg = { id: string; role: 'user'|'assistant'; text: string }

export function Chat() {
  const [prompt, setPrompt] = useState('')
  const [messages, setMessages] = useState<Msg[]>([])
  const [thinking, setThinking] = useState(false)
  const cancelRef = useRef<null | (() => void)>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    const p = prompt.trim()
    if (!p) return
    const id = Math.random().toString(36).slice(2)
    setMessages(m => [...m, { id, role: 'user', text: p }, { id: id + '-r', role: 'assistant', text: '' }])
    setPrompt('')
    setThinking(true)
    try {
      let reply = ''
      cancelRef.current = await api.askGPTStream(p, (chunk) => {
        reply += chunk
        setMessages(m => m.map(x => x.id === id + '-r' ? { ...x, text: reply } : x))
      })
    } catch {
      // ignore
    } finally {
      setThinking(false)
      cancelRef.current = null
    }
  }

  function cancel() {
    cancelRef.current?.()
    cancelRef.current = null
    setThinking(false)
  }

  return (
    <div className="col" style={{ gap: 16 }}>
      <h2>Ask AI About Expenses</h2>

      <Card title="Conversation">
        <div className="col" style={{ gap: 12 }}>
          {messages.map(m => (
            <div key={m.id} style={{ alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start', maxWidth: 720 }}>
              <div style={{ padding: '10px 12px', borderRadius: 12, background: m.role === 'user' ? 'rgba(110,168,254,0.15)' : 'rgba(255,255,255,0.05)', border: '1px solid var(--border)' }}>
                <div style={{ fontSize: 12, color: 'var(--muted)' }}>{m.role}</div>
                <div style={{ whiteSpace: 'pre-wrap' }}>{m.text}</div>
              </div>
            </div>
          ))}
          {thinking && <div className="chip blue">Thinking…</div>}
        </div>
      </Card>

      <Card title="Ask">
        <form className="row" onSubmit={onSubmit}>
          <textarea value={prompt} onChange={e => setPrompt(e.target.value)} rows={3} placeholder="Ask about your spending…" style={{ flex: 1, resize: 'vertical', padding: 10, borderRadius: 8, background: '#0f141b', color: 'var(--text)' }} />
          <button type="submit" disabled={thinking}>Send</button>
          {thinking && <button type="button" className="btn-ghost" onClick={cancel}>Stop</button>}
        </form>
      </Card>
    </div>
  )
}
