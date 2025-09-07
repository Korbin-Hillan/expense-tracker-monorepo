export function Footer() {
  const year = new Date().getFullYear()
  return (
    <footer className="footer">
      <div className="container row" style={{ justifyContent: 'space-between' }}>
        <div className="row" style={{ gap: 10, alignItems: 'center' }}>
          <div className="logo-sm" aria-hidden>€T</div>
          <span className="muted">Expense Tracker</span>
        </div>
        <div className="row" style={{ gap: 16 }}>
          <a className="muted" href="#" onClick={(e) => e.preventDefault()}>Privacy</a>
          <a className="muted" href="#" onClick={(e) => e.preventDefault()}>Terms</a>
          <span className="muted">© {year}</span>
        </div>
      </div>
    </footer>
  )
}

