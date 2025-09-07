import { useEffect, useState } from 'react'

type Theme = 'light' | 'dark'

function applyTheme(t: Theme) {
  document.documentElement.setAttribute('data-theme', t)
  localStorage.setItem('theme', t)
}

export function getInitialTheme(): Theme {
  const saved = (localStorage.getItem('theme') as Theme | null)
  if (saved === 'light' || saved === 'dark') return saved
  const prefersLight = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches
  return prefersLight ? 'light' : 'dark'
}

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>(() => (document.documentElement.getAttribute('data-theme') as Theme) || getInitialTheme())

  useEffect(() => {
    applyTheme(theme)
  }, [theme])

  function toggle() {
    setTheme(t => (t === 'light' ? 'dark' : 'light'))
  }

  const isLight = theme === 'light'

  return (
    <button className="btn-ghost" aria-label="Toggle theme" title="Toggle theme" onClick={toggle}>
      {isLight ? (
        // Moon icon
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
          <path d="M21 12.79A9 9 0 1 1 11.21 3a7 7 0 1 0 9.79 9.79z" />
        </svg>
      ) : (
        // Sun icon
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
          <path d="M6.76 4.84l-1.8-1.79-1.41 1.41 1.79 1.8 1.42-1.42zm10.48 0l1.79-1.8-1.41-1.41-1.8 1.79 1.42 1.42zM12 4V1h-2v3h2zm0 19v-3h-2v3h2zm8-9h3v-2h-3v2zM4 12H1v-2h3v2zm13.24 7.16l1.8 1.79 1.41-1.41-1.79-1.8-1.42 1.42zM6.76 19.16l-1.79 1.8 1.41 1.41 1.8-1.79-1.42-1.42zM12 8a4 4 0 100 8 4 4 0 000-8z"/>
        </svg>
      )}
    </button>
  )
}

