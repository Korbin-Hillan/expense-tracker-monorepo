import { api, LoginResponse, ApiUser } from '@/lib/api'

export type AuthState = {
  user: ApiUser | null
  token: string | null
  refreshToken: string | null
}

export const auth = {
  get state(): AuthState {
    return {
      user: JSON.parse(localStorage.getItem('user') || 'null'),
      token: localStorage.getItem('token'),
      refreshToken: localStorage.getItem('refresh_token'),
    }
  },
  setSession(data: LoginResponse) {
    localStorage.setItem('user', JSON.stringify(data.user))
    localStorage.setItem('token', data.token)
    localStorage.setItem('refresh_token', data.refresh_token)
  },
  clear() {
    localStorage.removeItem('user')
    localStorage.removeItem('token')
    localStorage.removeItem('refresh_token')
  },
  setUser(user: ApiUser) {
    localStorage.setItem('user', JSON.stringify(user))
  },
  async maybeRefresh(): Promise<void> {
    const rt = localStorage.getItem('refresh_token')
    if (!rt) return
    try {
      const next = await api.refresh(rt)
      localStorage.setItem('token', next.token)
      localStorage.setItem('refresh_token', next.refresh_token)
    } catch (e) {
      // if refresh fails, clear session
      auth.clear()
      throw e
    }
  },
}
