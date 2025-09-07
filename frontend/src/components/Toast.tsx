import { useEffect, useState } from 'react'

type ToastItem = { id: string; message: string; type: 'success'|'error'|'info' }

export function ToastViewport() {
  const [items, setItems] = useState<ToastItem[]>([])

  useEffect(() => {
    function onEvent(e: any) {
      const detail = e.detail as ToastItem
      setItems(prev => [...prev, detail])
      setTimeout(() => {
        setItems(prev => prev.filter(x => x.id !== detail.id))
      }, 3000)
    }
    window.addEventListener('app_toast', onEvent as any)
    return () => window.removeEventListener('app_toast', onEvent as any)
  }, [])

  return (
    <div style={{ position: 'fixed', top: 16, right: 16, display: 'flex', flexDirection: 'column', gap: 8, zIndex: 50 }}>
      {items.map(t => (
        <div key={t.id} className={`toast ${t.type}`}>
          {t.message}
        </div>
      ))}
    </div>
  )
}

