Expense Web (Vite + React + TS)

Quick start

- cd web
- Copy .env.example to .env and adjust API URL if needed
- npm install
- npm run dev

Notes

- During development, requests to /api/* are proxied to VITE_API_PROXY (default http://localhost:3000).
- In production builds, VITE_API_BASE_URL is used; set it to your backend URL.
- Auth stores token and refresh_token in localStorage and attaches Authorization: Bearer headers.

Initial pages

- Login and Register
- Dashboard (summary + budgets JSON placeholders)
- Transactions (list/add/delete)

