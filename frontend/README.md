Expense Web (Vite + React + TS)

Quick start

- cd frontend
- Copy `.env.example` to `.env` and adjust values if needed
- `npm install`
- `npm run dev`

Notes

- Dev proxy: Requests to `/api/*` are proxied to `VITE_API_PROXY` (default `http://localhost:3000`). If you set `VITE_API_BASE_URL`, the app will call that URL directly instead of using the proxy.
- Production: Set `VITE_API_BASE_URL` to your backend URL (e.g., `https://api.yourdomain.com`).
- Auth: Stores `token` and `refresh_token` in `localStorage` and attaches `Authorization: Bearer` headers.

Social sign-in

- Google: Set `VITE_GOOGLE_CLIENT_ID` in `frontend/.env`. In the backend, set `GOOGLE_WEB_CLIENT_ID` to the exact same client ID so verification passes.
- Apple (web): Set `VITE_APPLE_CLIENT_ID` and `VITE_APPLE_REDIRECT_URI` here. In the backend, set `APPLE_WEB_CLIENT_ID` to the same Services ID (client ID). iOS sign-in uses `APPLE_BUNDLE_ID` separately.

Available pages

- Login and Register
- Dashboard (summary and budgets)
- Transactions (list/add/delete)
- Imports, Insights/Chat, Budgets, Subscriptions, Recurring, Rules, Duplicates, Integrations, Settings
