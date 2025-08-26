import * as dotenv from "dotenv";
dotenv.config();

console.log("Domain:", process.env.AUTH0_DOMAIN);
console.log("Audience:", process.env.AUTH0_AUDIENCE);

import express, { type RequestHandler } from "express";
import { ObjectId } from "mongodb";
import { transactionsRouter } from "./routes/transactions.ts";

import { router as authRouter } from "./routes/auth-exchange.ts";
import { getJWKS } from "./keys.ts";
import { jwtVerify } from "jose";
import { createPublicKey } from "crypto";
import { getDb, usersCollection } from "./database/databaseConnection.js";
import { toApiUser } from "./types/user.ts";
import { ensureTransactionIndexes } from "./database/transactions.ts";

const app = express();
app.use(express.json());

app.get("/", async (_req, res) => {
  res.send("Hello World!");
});

app.use(authRouter);

app.get("/.well-known/jwks.json", async (_req, res) => {
  try {
    res.json(await getJWKS());
  } catch (e) {
    console.error("jwks error", e);
    res.status(500).json({ error: "failed_to_load_jwks" });
  }
});

const PUB_PEM = process.env.APP_JWT_PUBLIC_PEM!;
const APP_ISSUER = process.env.APP_JWT_ISSUER || "http://192.168.0.119:3000";

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
await ensureTransactionIndexes();
app.use(transactionsRouter);

// ---- Server ----
const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => {
  console.log(`Server running on http://192.168.0.119:${PORT}`);
});
