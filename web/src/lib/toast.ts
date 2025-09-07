export function toast(message: string, type: 'success'|'error'|'info' = 'info') {
  const id = Math.random().toString(36).slice(2) + Date.now().toString(36)
  window.dispatchEvent(new CustomEvent('app_toast', { detail: { id, message, type } }))
}

