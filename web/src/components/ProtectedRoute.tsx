import { ReactNode, useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { auth } from '@/state/auth'

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const [checking, setChecking] = useState(true)
  const [ok, setOk] = useState(false)

  useEffect(() => {
    let mounted = true
    async function run() {
      try {
        const hasToken = !!auth.state.token
        if (!hasToken && auth.state.refreshToken) {
          await auth.maybeRefresh()
        }
        if (!mounted) return
        setOk(!!auth.state.token)
      } finally {
        if (mounted) setChecking(false)
      }
    }
    run()
    return () => {
      mounted = false
    }
  }, [])

  if (checking) return <div className="container">Loading…</div>
  if (!ok) return <Navigate to="/login" />
  return <>{children}</>
}

