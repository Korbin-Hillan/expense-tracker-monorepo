import * as dotenv from "dotenv";
dotenv.config();

import { validateEnvironment } from "./utils/env-validation.ts";
validateEnvironment();

import express, { type RequestHandler } from "express";
import { ObjectId } from "mongodb";
import { transactionsRouter } from "./routes/transactions.ts";
import { importRouter } from "./routes/import.ts";

import { router as authRouter } from "./routes/auth-exchange.ts";
import { apiRateLimit, authRateLimit } from "./middleware/rate-limit.ts";
import { getJWKS } from "./keys.ts";
import { jwtVerify } from "jose";
import { createPublicKey } from "crypto";
import { getDb, usersCollection } from "./database/databaseConnection.js";
import { toApiUser } from "./types/user.ts";
import { ensureTransactionIndexes } from "./database/transactions.ts";
import http from "http";

const app = express();

// Apply rate limiting
app.use(apiRateLimit);
app.use("/auth", authRateLimit);

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
      
      // 4. Finally delete the user
      usersCollection(db).deleteOne({ _id: userId })
    ];

    const results = await Promise.all(operations);
    
    console.log(`✅ DELETE /api/account: Deleted data for user ${userId}:`, {
      refreshTokens: results[0].deletedCount,
      transactions: results[1].deletedCount, 
      expenses: results[2].deletedCount,
      user: results[3].deletedCount
    });

    if (results[3].deletedCount === 0) {
      res.status(404).json({ error: "user_not_found" });
      return;
    }

    res.json({ 
      success: true, 
      message: "Account and all data successfully deleted",
      deletedData: {
        refreshTokens: results[0].deletedCount,
        transactions: results[1].deletedCount,
        expenses: results[2].deletedCount
      }
    });
    
  } catch (e) {
    console.error("DELETE /api/account error:", e);
    
    if (e instanceof Error) {
      if (e.message.includes("missing_authorization") || e.message.includes("invalid_authorization")) {
        res.status(401).json({ error: "invalid_or_missing_authorization_header" });
        return;
      }
    }
    
    res.status(401).json({ error: "invalid_or_missing_app_jwt" });
  }
};

app.delete("/api/account", deleteAccountHandler);
await ensureTransactionIndexes();
app.use(transactionsRouter);
app.use(importRouter);

// ---- Server ----
const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://192.168.0.119:${PORT}`);
  console.log(`Also available at http://localhost:${PORT}`);
});
