import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { ToastViewport } from '@/components/Toast'
import './styles.css'

// Apply initial theme before render to avoid FOUC
(function applyInitialTheme() {
  try {
    const saved = localStorage.getItem('theme')
    if (saved === 'light' || saved === 'dark') {
      document.documentElement.setAttribute('data-theme', saved)
      return
    }
    const prefersLight = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches
    document.documentElement.setAttribute('data-theme', prefersLight ? 'light' : 'dark')
  } catch {
    document.documentElement.setAttribute('data-theme', 'dark')
  }
})()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <ToastViewport />
      <App />
    </BrowserRouter>
  </React.StrictMode>
)
