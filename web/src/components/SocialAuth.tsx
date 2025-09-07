import { useEffect, useRef, useState } from 'react'
import { api } from '@/lib/api'
import { auth } from '@/state/auth'
import { useNavigate } from 'react-router-dom'

declare global {
  interface Window {
    google?: any
    AppleID?: any
  }
}

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve()
    const s = document.createElement('script')
    s.src = src
    s.async = true
    s.onload = () => resolve()
    s.onerror = () => reject(new Error('failed_to_load_script'))
    document.head.appendChild(s)
  })
}

function GoogleIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="18" height="18">
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.4 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.7 1.1 7.8 3l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20c10 0 19-7.3 19-20 0-1.3-.1-2.3-.4-3.5z"/>
      <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.4 16.4 18.8 12 24 12c3 0 5.7 1.1 7.8 3l5.7-5.7C34 6.1 29.3 4 24 4 15.5 4 8.2 8.8 6.3 14.7z"/>
      <path fill="#4CAF50" d="M24 44c5.2 0 10-2 13.5-5.2l-6.2-5.1C29.2 35.5 26.8 36 24 36c-5.3 0-9.7-3.6-11.3-8.5l-6.6 5.1C8.2 39.2 15.5 44 24 44z"/>
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-1 2.9-3 5.2-5.6 6.7l.1.1 6.2 5.1c-.4.4 6-3.9 7.9-12.4.5-2 .8-4.1.8-6.6 0-1.3-.1-2.3-.4-3.5z"/>
    </svg>
  )
}

function AppleIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" width="18" height="18" fill="currentColor">
      <path d="M350.5 129.3c-18.8 22-45.7 36.9-73.7 35.1-3.6-28.6 10.1-58.7 27.7-77.3 20.3-21.1 54.6-36.6 82-37.1 3.5 28.4-9.4 58-36 79.3zM400 357.6c-10.9 25.2-24.1 50.5-42.2 73.4-22.3 28-53.7 59.5-92.6 59.9-35.5.4-44.9-23-93.3-22.8-48.4.2-58.6 23.2-94.1 22.8-38.9-.3-68.5-31.9-90.8-59.9C-35.3 377.9-8 255.3 39.8 187.7 62.9 154.2 98.2 132 135.2 131.5c37.2-.6 60.5 24.7 93.2 24.7 32.5 0 53.6-24.7 93.2-24.1 31.2.5 60.9 17 83.6 44.3-73.5 40.4-61.6 145.1-5.2 181.2z"/>
    </svg>
  )
}

export function GoogleSignInButton() {
  const [ready, setReady] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined

  useEffect(() => {
    if (!clientId) return
    let mounted = true
    loadScript('https://accounts.google.com/gsi/client').then(() => {
      if (!mounted || !window.google) return
      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: async (resp: any) => {
          try {
            const idToken = resp?.credential
            if (!idToken) return
            const session = await api.loginWithBearer(idToken)
            auth.setSession(session)
            navigate('/dashboard')
          } catch (e) {
            console.error('google login failed', e)
          }
        },
      })
      if (ref.current) {
        window.google.accounts.id.renderButton(ref.current, { theme: 'filled_black', size: 'large', text: 'continue_with', shape: 'rectangular', width: 260 })
        setReady(true)
      }
    })
    return () => { mounted = false }
  }, [clientId])

  if (!clientId) {
    return (
      <button className="btn-ghost" title="Set VITE_GOOGLE_CLIENT_ID in .env" disabled>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <GoogleIcon /> Continue with Google
        </span>
      </button>
    )
  }
  return (
    <div>
      <div ref={ref} />
    </div>
  )
}

export function AppleSignInButton() {
  const navigate = useNavigate()
  const [inited, setInited] = useState(false)
  const clientId = import.meta.env.VITE_APPLE_CLIENT_ID as string | undefined
  const redirectURI = (import.meta.env.VITE_APPLE_REDIRECT_URI as string | undefined) || window.location.origin + '/'
  const scope = (import.meta.env.VITE_APPLE_SCOPE as string | undefined) || 'name email'

  useEffect(() => {
    if (!clientId) return
    let mounted = true
    loadScript('https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js').then(() => {
      if (!mounted || !window.AppleID) return
      try {
        window.AppleID.auth.init({ clientId, scope, redirectURI, usePopup: true })
        setInited(true)
      } catch (e) {
        console.error('apple init failed', e)
      }
    })
    return () => { mounted = false }
  }, [clientId, redirectURI, scope])

  if (!clientId) {
    return (
      <button className="btn-ghost" title="Set VITE_APPLE_CLIENT_ID in .env" disabled>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <AppleIcon /> Continue with Apple
        </span>
      </button>
    )
  }

  async function signIn() {
    try {
      const resp = await window.AppleID.auth.signIn()
      const idToken = resp?.authorization?.id_token
      if (!idToken) return
      const session = await api.loginWithBearer(idToken)
      auth.setSession(session)
      navigate('/dashboard')
    } catch (e) {
      console.error('apple sign-in failed', e)
    }
  }

  return (
    <button onClick={signIn} disabled={!inited} className="btn-ghost" aria-label="Sign in with Apple">
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
        <AppleIcon /> Continue with Apple
      </span>
    </button>
  )
}
