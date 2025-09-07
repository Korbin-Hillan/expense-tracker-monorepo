import * as dotenv from "dotenv";
dotenv.config();

import { validateEnvironment } from "./utils/env-validation.ts";
validateEnvironment();

import express, { type RequestHandler } from "express";
import cors from "cors";
import helmet from "helmet";
import pinoHttp from "pino-http";
import bcrypt from "bcryptjs";
import fs from "fs";
import path from "path";
import { initMetrics, httpMetricsMiddleware, metricsHandler } from "./observability/metrics.ts";
import { initTelemetry } from "./observability/telemetry.ts";
import { ObjectId } from "mongodb";
import { transactionsRouter } from "./routes/transactions.ts";
import { importRouter } from "./routes/import.ts";
import { aiRouter } from "./routes/ai.ts";
import { budgetsRouter } from "./routes/budgets.ts";
import { recurringExpensesRouter } from "./routes/recurringExpenses.ts";
import { rulesRouter } from "./routes/rules.ts";
import { integrationsRouter } from "./routes/integrations.ts";
import { calendarRouter } from "./routes/calendar.ts";

import { router as authRouter } from "./routes/auth-exchange.ts";
import { apiRateLimit, authRateLimit } from "./middleware/rate-limit.ts";
import { requireAppJWT } from "./middleware/auth.ts";
import { getJWKS } from "./keys.ts";
import { jwtVerify } from "jose";
import { createPublicKey, randomUUID } from "crypto";
import { getDb, usersCollection } from "./database/databaseConnection.js";
import { toApiUser } from "./types/user.ts";
import { ensureTransactionIndexes } from "./database/transactions.ts";
import { ensureBudgetIndexes } from "./database/budgets.ts";
import { ensureRecurringExpenseIndexes } from "./database/recurringExpenses.ts";
import { ensureSubscriptionPrefsIndexes } from "./database/subscriptionPrefs.ts";
import { ensureAlertPrefsIndexes } from "./database/alertPrefs.ts";
import { ensureImportPresetIndexes } from "./database/importPresets.ts";
import { ensureRuleIndexes } from "./database/rules.ts";
import { ensureIntegrationIndexes } from "./database/integrations.ts";
import http from "http";

const app = express();
// Trust proxy when behind load balancers
app.set("trust proxy", Number(process.env.TRUST_PROXY || 1));

// Security headers
app.use(helmet());

// CORS
const isProd = process.env.NODE_ENV === "production";
const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: (origin, cb) => {
      if (!isProd) return cb(null, true);
      if (!origin) return cb(null, false);
      if (allowedOrigins.includes(origin)) return cb(null, true);
      return cb(new Error("CORS not allowed"));
    },
    credentials: true,
  })
);

// Structured logging with request IDs
app.use(
  pinoHttp({
    genReqId: (req) => (req.headers["x-request-id"] as string) || randomUUID(),
    redact: {
      // Avoid logging auth/cookie headers
      paths: [
        'req.headers.authorization',
        'req.headers.cookie'
      ],
      censor: '[Redacted]'
    },
    autoLogging: true,
    customLogLevel: (_req, res, err) => {
      if (err) return 'error';
      if (res.statusCode >= 500) return 'error';
      if (res.statusCode >= 400) return 'warn';
      return 'info';
    },
  })
);

// Metrics
initTelemetry();
initMetrics();
app.use(httpMetricsMiddleware);

// Apply rate limiting
app.use(apiRateLimit);
app.use("/auth", authRateLimit);

app.use(express.json({ limit: '2mb' }));
// Serve uploaded avatars
const UPLOAD_ROOT = path.resolve(process.cwd(), 'uploads');
const AVATAR_DIR = path.join(UPLOAD_ROOT, 'avatars');
const RECEIPT_DIR = path.join(UPLOAD_ROOT, 'receipts');
try { fs.mkdirSync(AVATAR_DIR, { recursive: true }); } catch {}
try { fs.mkdirSync(RECEIPT_DIR, { recursive: true }); } catch {}
app.use('/uploads', express.static(UPLOAD_ROOT));

// Liveness/Readiness probes
app.get("/healthz", (_req, res) => res.status(200).send("ok"));
app.get("/readyz", async (_req, res) => {
  try {
    const db = await getDb();
    await db.command({ ping: 1 });
    res.status(200).send("ready");
  } catch {
    res.status(503).send("not_ready");
  }
});
app.get("/metrics", metricsHandler);

app.get("/", async (_req, res) => {
  res.send("Hello World!");
});

app.use(authRouter);

// Disable caching for AI endpoints to avoid 304/empty bodies in clients
app.use((req, res, next) => {
  if (req.path.startsWith('/api/ai/')) {
    // prevent conditional requests from short-circuiting responses
    try { delete (req.headers as any)['if-none-match']; } catch {}
    res.set({
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
      'Surrogate-Control': 'no-store',
    });
  }
  next();
});
app.use(aiRouter);
app.use(budgetsRouter);
app.use(recurringExpensesRouter);
app.use(rulesRouter);
app.use(integrationsRouter);
app.use(calendarRouter);

app.get("/.well-known/jwks.json", async (_req, res) => {
  try {
    res.json(await getJWKS());
  } catch (e) {
    console.error("jwks error", e);
    res.status(500).json({ error: "failed_to_load_jwks" });
  }
});

const PUB_PEM = process.env.APP_JWT_PUBLIC_PEM!;
const APP_ISSUER = process.env.APP_JWT_ISSUER!;

// --- Password strength helper ---
function checkPasswordStrength(pw: string): { ok: boolean; reason?: string } {
  if (typeof pw !== 'string' || pw.length < 8) return { ok: false, reason: 'min_8_chars' };
  const lower = /[a-z]/.test(pw);
  const upper = /[A-Z]/.test(pw);
  const digit = /\d/.test(pw);
  const symbol = /[^\w\s]/.test(pw);
  const classes = [lower, upper, digit, symbol].filter(Boolean).length;
  if (classes < 3) return { ok: false, reason: 'use_mix_of_upper_lower_digit_symbol' };
  const common = new Set(['password','123456','qwerty','letmein','abc123','111111','123456789','iloveyou']);
  if (common.has(pw.toLowerCase())) return { ok: false, reason: 'too_common' };
  return { ok: true };
}

async function verifyAppJWT(authz?: string) {
  if (!authz) throw new Error("missing_authorization");
  const m = /^Bearer (.+)$/.exec(authz);
  if (!m) throw new Error("invalid_authorization");
  const token = m[1];
  const key = createPublicKey(PUB_PEM);
  const { payload } = await jwtVerify(token, key, {
    issuer: APP_ISSUER,
    clockTolerance: 60,
  });
  return payload; // { sub, roles, ver, iat, exp, ... }
}

// ---- Handlers (typed) ----
const meHandler: RequestHandler = async (req, res) => {
  try {
    const payload = await verifyAppJWT(req.header("authorization"));
    const db = await getDb();

    const userId = String(payload.sub); // sub = user._id.toString() when you signed the app JWT
    const user = await usersCollection(db).findOne({
      _id: new ObjectId(userId),
    });
    if (!user) {
      res.status(404).json({ error: "user_not_found" });
      return;
    }

    res.json({ user: toApiUser(user) });
    return;
  } catch (e) {
    console.error("GET /api/me error:", e);
    res.status(401).json({ error: "invalid_or_missing_app_jwt" });
    return;
  }
};

// Register on both paths (no _router hacks, no redirect needed)
app.get("/api/me", meHandler);
app.get("/api/user/me", meHandler);

// Update timezone
app.put("/api/user/timezone", requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const tz = String(req.body?.timezone || '').trim();
    if (!tz) { res.status(400).json({ error: 'timezone_required' }); return; }
    const db = await getDb();
    const result = await usersCollection(db).updateOne({ _id: userId }, { $set: { timezone: tz, updatedAt: new Date() } });
    if (!result.matchedCount) { res.status(404).json({ error: 'user_not_found' }); return; }
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'update_failed' });
  }
});

// Update profile (name/timezone)
app.put("/api/user/profile", requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const nameRaw = req.body?.name;
    const tzRaw = req.body?.timezone;
    const update: any = { updatedAt: new Date() };
    if (typeof nameRaw === 'string') update.name = nameRaw.trim() || null;
    if (typeof tzRaw === 'string') update.timezone = tzRaw.trim();
    if (Object.keys(update).length === 1) { res.status(400).json({ error: 'no_fields_to_update' }); return; }
    const db = await getDb();
    const upd = await usersCollection(db).updateOne({ _id: userId }, { $set: update });
    if (!upd.matchedCount) { res.status(404).json({ error: 'user_not_found' }); return; }
    const user = await usersCollection(db).findOne({ _id: userId });
    if (!user) { res.status(404).json({ error: 'user_not_found' }); return; }
    res.json({ user: toApiUser(user) });
  } catch (e) {
    res.status(500).json({ error: 'update_failed' });
  }
});

// Update email (password accounts only)
app.put("/api/user/email", requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const newEmailRaw = String(req.body?.newEmail || '').trim().toLowerCase();
    const currentPassword = String(req.body?.currentPassword || '');
    if (!newEmailRaw || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmailRaw)) {
      res.status(400).json({ error: 'invalid_email' });
      return;
    }
    const db = await getDb();
    const col = usersCollection(db);
    const user = await col.findOne({ _id: userId });
    if (!user) { res.status(404).json({ error: 'user_not_found' }); return; }
    if (user.provider !== 'password') {
      res.status(400).json({ error: 'email_change_not_supported' });
      return;
    }
    if (!user.passwordHash) { res.status(400).json({ error: 'no_password_set' }); return; }
    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) { res.status(401).json({ error: 'invalid_current_password' }); return; }
    const exists = await col.findOne({ email: newEmailRaw });
    if (exists && String(exists._id) !== String(userId)) {
      res.status(409).json({ error: 'email_in_use' });
      return;
    }
    await col.updateOne({ _id: userId }, { $set: { email: newEmailRaw, updatedAt: new Date() } });
    const updated = await col.findOne({ _id: userId });
    res.json({ user: toApiUser(updated!) });
  } catch (e) {
    res.status(500).json({ error: 'update_email_failed' });
  }
});

// Update avatar (data URL, saved to /uploads/avatars)
app.put("/api/user/avatar", requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const dataUrl = String(req.body?.avatar || '');
    if (!dataUrl.startsWith('data:image/')) { res.status(400).json({ error: 'invalid_image' }); return; }
    // crude size guard: dataUrl length ~1.37 * bytes
    if (dataUrl.length > 1_400_000) { res.status(413).json({ error: 'image_too_large' }); return; }

    // Parse data URL
    const m = /^data:(image\/(png|jpeg|webp));base64,(.+)$/.exec(dataUrl);
    if (!m) { res.status(400).json({ error: 'invalid_image' }); return; }
    const ext = m[2] === 'jpeg' ? 'jpg' : m[2];
    const b64 = m[3];
    const buf = Buffer.from(b64, 'base64');
    if (buf.length > 1024 * 1024) { res.status(413).json({ error: 'image_too_large' }); return; }
    const filename = `${String(userId)}.${ext}`;
    const filePath = path.join(AVATAR_DIR, filename);
    fs.writeFileSync(filePath, buf);
    const url = `/uploads/avatars/${filename}?v=${Date.now()}`;

    const db = await getDb();
    await usersCollection(db).updateOne({ _id: userId }, { $set: { avatarUrl: url, updatedAt: new Date() } });
    const user = await usersCollection(db).findOne({ _id: userId });
    if (!user) { res.status(404).json({ error: 'user_not_found' }); return; }
    res.json({ user: toApiUser(user) });
  } catch (e) {
    res.status(500).json({ error: 'update_avatar_failed' });
  }
});

// Update password (current + new)
app.put('/api/user/password', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const currentPassword = String(req.body?.currentPassword || '');
    const newPassword = String(req.body?.newPassword || '');
    const strength = checkPasswordStrength(newPassword);
    if (!strength.ok) { res.status(400).json({ error: 'weak_password', reason: strength.reason }); return; }
    const db = await getDb();
    const col = usersCollection(db);
    const user = await col.findOne({ _id: userId });
    if (!user) { res.status(404).json({ error: 'user_not_found' }); return; }
    if (user.provider !== 'password' || !user.passwordHash) { res.status(400).json({ error: 'password_change_not_supported' }); return; }
    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) { res.status(401).json({ error: 'invalid_current_password' }); return; }
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await col.updateOne({ _id: userId }, { $set: { passwordHash, updatedAt: new Date() } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'update_password_failed' });
  }
});

// --- Email change with verification ---
app.post('/api/user/email/request-change', requireAppJWT as any, async (req, res) => {
  try {
    const userId = new ObjectId(String((req as any).userId));
    const newEmail = String(req.body?.newEmail || '').trim().toLowerCase();
    const currentPassword = String(req.body?.currentPassword || '');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) { res.status(400).json({ error: 'invalid_email' }); return; }
    const db = await getDb();
    const col = usersCollection(db);
    const user = await col.findOne({ _id: userId });
    if (!user) { res.status(404).json({ error: 'user_not_found' }); return; }
    if (user.provider !== 'password' || !user.passwordHash) { res.status(400).json({ error: 'email_change_not_supported' }); return; }
    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) { res.status(401).json({ error: 'invalid_current_password' }); return; }
    const exists = await col.findOne({ email: newEmail });
    if (exists && String(exists._id) !== String(userId)) { res.status(409).json({ error: 'email_in_use' }); return; }
    const token = Buffer.from(crypto.randomUUID()).toString('base64url');
    const emailCol = (await getDb()).collection('email_verifications');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 30); // 30 minutes
    await emailCol.insertOne({ userId, newEmail, token, used: false, createdAt: new Date(), expiresAt });
    const verifyUrl = `${APP_ISSUER}/api/user/email/verify?token=${token}`;
    console.log(`[email] Verify email for user ${userId} -> ${newEmail}: ${verifyUrl}`);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'request_email_change_failed' });
  }
});

app.get('/api/user/email/verify', async (req, res) => {
  try {
    const token = String(req.query?.token || '');
    if (!token) { res.status(400).json({ error: 'missing_token' }); return; }
    const db = await getDb();
    const emailCol = db.collection<any>('email_verifications');
    const rec = await emailCol.findOne({ token });
    if (!rec) { res.status(400).json({ error: 'invalid_token' }); return; }
    if (rec.used) { res.status(400).json({ error: 'token_used' }); return; }
    if (new Date(rec.expiresAt).getTime() < Date.now()) { res.status(400).json({ error: 'token_expired' }); return; }
    const col = usersCollection(db);
    const exists = await col.findOne({ email: rec.newEmail });
    if (exists && String(exists._id) !== String(rec.userId)) { res.status(409).json({ error: 'email_in_use' }); return; }
    await col.updateOne({ _id: new ObjectId(String(rec.userId)) }, { $set: { email: rec.newEmail, updatedAt: new Date() } });
    await emailCol.updateOne({ _id: rec._id }, { $set: { used: true, usedAt: new Date() } });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'verify_email_failed' });
  }
});

// DELETE account endpoint
const deleteAccountHandler: RequestHandler = async (req, res) => {
  try {
    const payload = await verifyAppJWT(req.headers.authorization);
    const userId = new ObjectId(String(payload.sub));

    console.log(`🗑️ DELETE /api/account: Deleting account for user ${userId}`);

    const db = await getDb();

    // Delete all user data in the correct order to avoid foreign key issues
    const operations = [
      // 1. Delete refresh tokens
      db.collection("refresh_tokens").deleteMany({ userId }),

      // 2. Delete transactions
      db.collection("transactions").deleteMany({ userId }),

      // 3. Delete expenses
      db.collection("expenses").deleteMany({ userId }),

      // 4. Delete recurring expenses
      db.collection("recurringExpenses").deleteMany({ userId }),

      // 5. Finally delete the user
      usersCollection(db).deleteOne({ _id: userId }),
    ];

    const results = await Promise.all(operations);

    console.log(`✅ DELETE /api/account: Deleted data for user ${userId}:`, {
      refreshTokens: results[0].deletedCount,
      transactions: results[1].deletedCount,
      expenses: results[2].deletedCount,
      recurringExpenses: results[3].deletedCount,
      user: results[4].deletedCount,
    });

    if (results[4].deletedCount === 0) {
      res.status(404).json({ error: "user_not_found" });
      return;
    }

    res.json({
      success: true,
      message: "Account and all data successfully deleted",
      deletedData: {
        refreshTokens: results[0].deletedCount,
        transactions: results[1].deletedCount,
        expenses: results[2].deletedCount,
        recurringExpenses: results[3].deletedCount,
      },
    });
  } catch (e) {
    console.error("DELETE /api/account error:", e);

    if (e instanceof Error) {
      if (
        e.message.includes("missing_authorization") ||
        e.message.includes("invalid_authorization")
      ) {
        res
          .status(401)
          .json({ error: "invalid_or_missing_authorization_header" });
        return;
      }
    }

    res.status(401).json({ error: "invalid_or_missing_app_jwt" });
  }
};

app.delete("/api/account", deleteAccountHandler);
await ensureTransactionIndexes();
await ensureBudgetIndexes();
await ensureRecurringExpenseIndexes();
await ensureSubscriptionPrefsIndexes();
await ensureAlertPrefsIndexes();
await ensureImportPresetIndexes();
await ensureRuleIndexes();
await ensureIntegrationIndexes();
app.use(transactionsRouter);
app.use(importRouter);

// ---- Server ----
const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server listening on 0.0.0.0:${PORT}`);
  if (process.env.APP_JWT_ISSUER) {
    console.log(`Issuer: ${process.env.APP_JWT_ISSUER}`);
  }
});
