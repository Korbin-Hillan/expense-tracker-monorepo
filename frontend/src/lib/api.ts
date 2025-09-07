export type ApiUser = {
  id: string
  email: string | null
  name?: string | null
  avatarUrl?: string | null
  provider?: 'apple' | 'google' | 'password' | null
  roles?: string[]
  timezone?: string | null
}

export type LoginResponse = {
  token: string
  refresh_token: string
  user: ApiUser
}

export type Transaction = {
  id: string
  type: 'expense' | 'income'
  amount: number
  category: string
  note: string | null
  tags?: string[]
  receiptUrl?: string | null
  date: string // ISO string
}

const BASE_URL = import.meta.env.VITE_API_BASE_URL || '' // use dev proxy when empty

function authHeaders(): Record<string, string> {
  const token = localStorage.getItem('token')
  return token ? { Authorization: `Bearer ${token}` } : {}
}

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(text || `HTTP ${res.status}`)
  }
  return (await res.json()) as T
}

export const api = {
  async login(email: string, password: string) {
    const res = await fetch(`${BASE_URL}/api/auth/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
    return handle<LoginResponse>(res)
  },
  // Integrations
  async listIntegrations() {
    const res = await fetch(`${BASE_URL}/api/integrations`, { headers: { ...authHeaders() } })
    return handle<{ integrations: any[] }>(res)
  },
  async disconnectIntegration(provider: string) {
    const res = await fetch(`${BASE_URL}/api/integrations/disconnect`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders() }, body: JSON.stringify({ provider }) })
    return handle<{ success: boolean }>(res)
  },
  async createPlaidLinkToken() {
    const res = await fetch(`${BASE_URL}/api/integrations/plaid/link-token`, { method: 'POST', headers: { ...authHeaders() } })
    return handle<{ link_token: string; sandbox?: boolean }>(res)
  },
  async exchangePlaidPublicToken(public_token: string) {
    const res = await fetch(`${BASE_URL}/api/integrations/plaid/exchange`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders() }, body: JSON.stringify({ public_token }) })
    return handle<{ success: boolean }>(res)
  },
  // Rules
  async listRules() {
    const res = await fetch(`${BASE_URL}/api/rules`, { headers: { ...authHeaders() } })
    return handle<{ rules: any[] }>(res)
  },
  async saveRule(rule: { id?: string; name: string; order?: number; enabled?: boolean; when: { field: string; type: string; value: string }; set: { category?: string; tags?: string[] } }) {
    const res = await fetch(`${BASE_URL}/api/rules`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders() }, body: JSON.stringify(rule) })
    return handle<{ rule: any }>(res)
  },
  async deleteRule(id: string) {
    const res = await fetch(`${BASE_URL}/api/rules/${id}`, { method: 'DELETE', headers: { ...authHeaders() } })
    return handle<{ success: boolean }>(res)
  },
  async applyRules() {
    const res = await fetch(`${BASE_URL}/api/rules/apply`, { method: 'POST', headers: { ...authHeaders() } })
    return handle<{ updated: number }>(res)
  },
  async loginWithBearer(idToken: string) {
    const res = await fetch(`${BASE_URL}/api/auth/session`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${idToken}` },
    })
    return handle<LoginResponse>(res)
  },
  async updateTransaction(id: string, input: { type: 'expense'|'income'; amount: number; category: string; note?: string|null; date?: string; tags?: string[] }) {
    const res = await fetch(`${BASE_URL}/api/transactions/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify(input),
    })
    return handle<Transaction>(res)
  },
  // Budgets
  async listBudgets() {
    const res = await fetch(`${BASE_URL}/api/budgets`, { headers: { ...authHeaders() } })
    return handle<{ id: string; category: string; monthly: number }[]>(res)
  },
  async uploadReceipt(id: string, file: File) {
    const fd = new FormData()
    fd.append('file', file)
    const res = await fetch(`${BASE_URL}/api/transactions/${id}/receipt`, { method: 'POST', headers: { ...authHeaders() as any }, body: fd } as any)
    return handle<{ success: boolean; receiptUrl: string }>(res)
  },
  async deleteReceipt(id: string) {
    const res = await fetch(`${BASE_URL}/api/transactions/${id}/receipt`, { method: 'DELETE', headers: { ...authHeaders() } })
    return handle<{ success: boolean }>(res)
  },
  async putBudgets(budgets: { category: string; monthly: number }[]) {
    const res = await fetch(`${BASE_URL}/api/budgets`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ budgets }),
    })
    return handle<{ success: boolean; budgets: { id: string; category: string; monthly: number }[] }>(res)
  },
  async register(email: string, password: string, name?: string) {
    const res = await fetch(`${BASE_URL}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, name }),
    })
    return handle<LoginResponse>(res)
  },
  async refresh(refreshToken: string) {
    const res = await fetch(`${BASE_URL}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    })
    return handle<{ token: string; refresh_token: string }>(res)
  },
  // User
  async me() {
    const res = await fetch(`${BASE_URL}/api/me`, { headers: { ...authHeaders() } })
    return handle<{ user: ApiUser }>(res)
  },
  async updateTimezone(timezone: string) {
    const res = await fetch(`${BASE_URL}/api/user/timezone`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ timezone })
    })
    return handle<{ success: boolean }>(res)
  },
  async updateProfile(input: { name?: string | null; timezone?: string | null }) {
    const res = await fetch(`${BASE_URL}/api/user/profile`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify(input)
    })
    return handle<{ user: ApiUser }>(res)
  },
  async updateEmail(newEmail: string, currentPassword: string) {
    const res = await fetch(`${BASE_URL}/api/user/email`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ newEmail, currentPassword })
    })
    return handle<{ user: ApiUser }>(res)
  },
  async updatePassword(currentPassword: string, newPassword: string) {
    const res = await fetch(`${BASE_URL}/api/user/password`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ currentPassword, newPassword })
    })
    return handle<{ success: boolean }>(res)
  },
  async updateAvatar(avatar: string) {
    const res = await fetch(`${BASE_URL}/api/user/avatar`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ avatar })
    })
    return handle<{ user: ApiUser }>(res)
  },
  // Import: columns detection
  async importColumns(file: File) {
    const fd = new FormData()
    fd.append('file', file)
    const res = await fetch(`${BASE_URL}/api/import/columns`, {
      method: 'POST',
      headers: { ...authHeaders() as any },
      body: fd,
    } as any)
    return handle<{ columns: string[]; sheets?: string[]; suggestedMapping?: Partial<Record<'date'|'description'|'amount'|'type'|'category'|'note', string>>; signature?: string; preset?: { name: string; mapping: any } }>(res)
  },
  async importPreview(file: File, mapping: { date?: string; description?: string; amount?: string; type?: string; category?: string; note?: string }) {
    const fd = new FormData()
    fd.append('file', file)
    if (mapping.date) fd.append('dateColumn', mapping.date)
    if (mapping.description) fd.append('descriptionColumn', mapping.description)
    if (mapping.amount) fd.append('amountColumn', mapping.amount)
    if (mapping.type) fd.append('typeColumn', mapping.type)
    if (mapping.category) fd.append('categoryColumn', mapping.category)
    if (mapping.note) fd.append('noteColumn', mapping.note)
    const res = await fetch(`${BASE_URL}/api/import/preview`, {
      method: 'POST',
      headers: { ...authHeaders() as any },
      body: fd,
    } as any)
    return handle<{ previewRows: any[]; totalRows: number; errors: string[]; duplicates: any[]; suggestedMapping?: any }>(res)
  },
  async saveImportPreset(signature: string, name: string, mapping: any) {
    const res = await fetch(`${BASE_URL}/api/import/presets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ signature, name, mapping })
    })
    return handle<{ preset: { name: string; signature: string } }>(res)
  },
  async importCommit(opts: { file: File; mapping: { date?: string; description?: string; amount?: string; type?: string; category?: string; note?: string }; skipDuplicates?: boolean; overwriteDuplicates?: boolean; useAI?: boolean; applyAICategory?: boolean }) {
    const fd = new FormData()
    fd.append('file', opts.file)
    const { mapping } = opts
    if (mapping.date) fd.append('dateColumn', mapping.date)
    if (mapping.description) fd.append('descriptionColumn', mapping.description)
    if (mapping.amount) fd.append('amountColumn', mapping.amount)
    if (mapping.type) fd.append('typeColumn', mapping.type)
    if (mapping.category) fd.append('categoryColumn', mapping.category)
    if (mapping.note) fd.append('noteColumn', mapping.note)
    if (opts.skipDuplicates != null) fd.append('skipDuplicates', String(!!opts.skipDuplicates))
    if (opts.overwriteDuplicates != null) fd.append('overwriteDuplicates', String(!!opts.overwriteDuplicates))
    if (opts.useAI != null) fd.append('useAI', String(!!opts.useAI))
    if (opts.applyAICategory != null) fd.append('applyAICategory', String(!!opts.applyAICategory))
    const res = await fetch(`${BASE_URL}/api/import/commit`, {
      method: 'POST',
      headers: { ...authHeaders() as any },
      body: fd,
    } as any)
    return handle<{ success: boolean; totalProcessed: number; inserted: number; updated: number; duplicatesSkipped: number; errors: string[]; summary: { totalRows: number } }>(res)
  },
  async importJobStatus(id: string) {
    const res = await fetch(`${BASE_URL}/api/import/job/${encodeURIComponent(id)}`, { headers: { ...authHeaders() } })
    return handle<any>(res)
  },
  async deleteAccount() {
    const res = await fetch(`${BASE_URL}/api/account`, { method: 'DELETE', headers: { ...authHeaders() } })
    return handle<{ success: boolean }>(res)
  },
  async resetPassword(email: string, newPassword: string) {
    const res = await fetch(`${BASE_URL}/api/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, newPassword })
    })
    return handle<{ message: string }>(res)
  },
  async requestEmailChange(newEmail: string, currentPassword: string) {
    const res = await fetch(`${BASE_URL}/api/user/email/request-change`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ newEmail, currentPassword })
    })
    return handle<{ success: boolean }>(res)
  },
  async verifyEmailToken(token: string) {
    const res = await fetch(`${BASE_URL}/api/user/email/verify?token=${encodeURIComponent(token)}`)
    return handle<{ success: boolean }>(res)
  },
  async listTransactions(limit = 20, skip = 0) {
    const params = new URLSearchParams({ limit: String(limit), skip: String(skip) })
    const res = await fetch(`${BASE_URL}/api/transactions?${params.toString()}`, {
      headers: { ...authHeaders() },
    })
    return handle<Transaction[]>(res)
  },
  async addTransaction(input: Omit<Transaction, 'id' | 'date'> & { date?: string }) {
    const res = await fetch(`${BASE_URL}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify(input),
    })
    return handle<Transaction>(res)
  },
  async askGPTStream(prompt: string, onChunk: (text: string) => void) {
    const res = await fetch(`${BASE_URL}/api/ai/assistant/gpt/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream', ...authHeaders() },
      body: JSON.stringify({ prompt }),
    })
    if (!res.ok || !res.body) throw new Error('stream_failed')
    const reader = res.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ''
    let cancelled = false
    async function pump() {
      while (!cancelled) {
        const { done, value } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })
        // Parse SSE lines
        const parts = buffer.split('\n\n')
        buffer = parts.pop() || ''
        for (const p of parts) {
          for (const line of p.split('\n')) {
            const m = /^data:\s?(.*)$/.exec(line)
            if (m) onChunk(m[1])
          }
        }
      }
    }
    pump()
    return () => { cancelled = true; try { reader.cancel() } catch {} }
  },
  async deleteTransaction(id: string) {
    const res = await fetch(`${BASE_URL}/api/transactions/${id}`, {
      method: 'DELETE',
      headers: { ...authHeaders() },
    })
    if (!res.ok) throw new Error('delete_failed')
  },
  async listDuplicates() {
    const res = await fetch(`${BASE_URL}/api/transactions/duplicates`, { headers: { ...authHeaders() } })
    return handle<{ groups: { key: string; items: { id: string; date: string; amount: number; note: string }[] }[] }>(res)
  },
  async resolveDuplicates(keepId: string, deleteIds: string[]) {
    const res = await fetch(`${BASE_URL}/api/transactions/duplicates/resolve`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders() }, body: JSON.stringify({ keepId, deleteIds }) })
    return handle<{ deleted: number }>(res)
  },
  async summary(params?: { startDate?: string; endDate?: string; category?: string; type?: string }) {
    const qs = new URLSearchParams()
    if (params?.startDate) qs.set('startDate', params.startDate)
    if (params?.endDate) qs.set('endDate', params.endDate)
    if (params?.category) qs.set('category', params.category)
    if (params?.type) qs.set('type', params.type)
    const url = `${BASE_URL}/api/transactions/summary${qs.toString() ? `?${qs.toString()}` : ''}`
    const res = await fetch(url, { headers: { ...authHeaders() } })
    return handle<any>(res)
  },
  async exportTransactionsCSV(params?: { startDate?: string; endDate?: string; category?: string; type?: string }): Promise<Blob> {
    const qs = new URLSearchParams()
    if (params?.startDate) qs.set('startDate', params.startDate)
    if (params?.endDate) qs.set('endDate', params.endDate)
    if (params?.category) qs.set('category', params.category)
    if (params?.type) qs.set('type', params.type)
    const res = await fetch(`${BASE_URL}/api/transactions/export/csv${qs.toString() ? `?${qs.toString()}` : ''}`, { headers: { ...authHeaders() } })
    if (!res.ok) throw new Error('export_failed')
    return await res.blob()
  },
  async exportTransactionsExcel(params?: { startDate?: string; endDate?: string; category?: string; type?: string }): Promise<Blob> {
    const qs = new URLSearchParams()
    if (params?.startDate) qs.set('startDate', params.startDate)
    if (params?.endDate) qs.set('endDate', params.endDate)
    if (params?.category) qs.set('category', params.category)
    if (params?.type) qs.set('type', params.type)
    const res = await fetch(`${BASE_URL}/api/transactions/export/excel${qs.toString() ? `?${qs.toString()}` : ''}`, { headers: { ...authHeaders() } })
    if (!res.ok) throw new Error('export_failed')
    return await res.blob()
  },
  async budgetsStatus() {
    const res = await fetch(`${BASE_URL}/api/budgets/status`, {
      headers: { ...authHeaders() },
    })
    return handle<any>(res)
  },
  // AI: insights (GPT payload)
  async gptInsights() {
    const res = await fetch(`${BASE_URL}/api/ai/insights/gpt`, { headers: { ...authHeaders() } })
    return handle<{ insights: any[]; narrative?: string; savings_playbook?: any; budget?: any; subscriptions?: any }>(res)
  },
  async weeklyDigest() {
    const res = await fetch(`${BASE_URL}/api/ai/digest/gpt`, { headers: { ...authHeaders() } })
    return handle<{ digest: string }>(res)
  },
  async askGPT(prompt: string) {
    const res = await fetch(`${BASE_URL}/api/ai/assistant/gpt`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ prompt }),
    })
    return handle<{ reply: string }>(res)
  },
  async healthScore() {
    const res = await fetch(`${BASE_URL}/api/ai/health-score`, { headers: { ...authHeaders() } })
    return handle<any>(res)
  },
  async alerts() {
    const res = await fetch(`${BASE_URL}/api/ai/alerts`, { headers: { ...authHeaders() } })
    return handle<{ alerts: any[] }>(res)
  },
  // Subscriptions
  async subscriptions() {
    const res = await fetch(`${BASE_URL}/api/ai/subscriptions`, { headers: { ...authHeaders() } })
    return handle<{ subs: { note: string; count: number; avg: number; monthlyEstimate: number; frequency: string }[] }>(res)
  },
  async setSubscriptionPref(note: string, opts: { ignore?: boolean; cancel?: boolean }) {
    const res = await fetch(`${BASE_URL}/api/ai/subscriptions/prefs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ note, ...opts }),
    })
    return handle<{ success: boolean }>(res)
  },
  async exportSubscriptionsCSV(): Promise<Blob> {
    const res = await fetch(`${BASE_URL}/api/ai/subscriptions/export.csv`, { headers: { ...authHeaders() } })
    if (!res.ok) throw new Error('export_failed')
    return await res.blob()
  },
  // Recurring
  async recurringExpenses() {
    const res = await fetch(`${BASE_URL}/api/recurring-expenses`, { headers: { ...authHeaders() } })
    return handle<{ recurringExpenses: any[] }>(res)
  },
  async toggleRecurring(id: string) {
    const res = await fetch(`${BASE_URL}/api/recurring-expenses/${id}/toggle`, {
      method: 'PATCH',
      headers: { ...authHeaders() },
    })
    return handle<{ success: boolean; isActive: boolean }>(res)
  },
}
