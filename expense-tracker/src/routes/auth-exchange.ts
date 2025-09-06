import express, { RequestHandler } from "express";
import bcrypt from "bcryptjs";
import crypto from "crypto";
import {
  verifyAppleIdToken,
  verifyGoogleIdToken,
} from "../api/auth0-verify.ts";
import {
  upsertUser,
  findUserByEmail,
  createUserWithPassword,
} from "../store.ts";
import {
  usersCollection,
  refreshTokensCollection,
  getDb,
} from "../database/databaseConnection.js";
import { signAppJWT } from "../keys.ts";
import { toApiUser } from "../types/user.ts";

export const router = express.Router();

/** Issue an opaque refresh token as "<selector>.<verifier>" and store {selector, hash(verifier)} */
function mintRefreshTokenDoc(userId: any) {
  const selector = crypto.randomUUID(); // lookup key
  const verifier = crypto.randomBytes(32).toString("base64url"); // secret
  const token = `${selector}.${verifier}`;
  return {
    token, // return to client
    doc: {
      selector,
      hash: bcrypt.hashSync(verifier, 12),
      userId,
      jti: crypto.randomUUID(),
      revoked: false,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30), // 30d
    },
  };
}

async function verifyAndRotateRefreshToken(rt: string) {
  const [selector, verifier] = rt.split(".");
  if (!selector || !verifier) throw new Error("bad_format");
  const db = await getDb();
  const col = refreshTokensCollection(db);
  const doc = await col.findOne({
    selector,
    revoked: false,
    expiresAt: { $gt: new Date() },
  });

  if (!doc) throw new Error("not_found");
  const ok = await bcrypt.compare(verifier, doc.hash);
  if (!ok) throw new Error("bad_verifier");

  // rotate
  await col.updateOne(
    { _id: doc._id },
    { $set: { revoked: true, revokedAt: new Date() } }
  );
  const { token: newToken, doc: newDoc } = mintRefreshTokenDoc(doc.userId);
  await col.insertOne(newDoc);
  return { userId: doc.userId, newToken };
}

/** POST /api/auth/session  (Apple / Google via Bearer OR email+password via JSON body) */
const createSession: RequestHandler = async (req, res) => {
  // If Authorization present → Treat as Apple/Google
  const authz = req.header("authorization");
  const bearer = authz && /^Bearer (.+)$/.exec(authz)?.[1];

  try {
    const db = await getDb();

    if (bearer) {
      // peek iss to route (base64url-safe)
      let iss: string | undefined;
      try {
        const payloadB64 = bearer.split(".")[1];
        const b64 =
          payloadB64.replace(/-/g, "+").replace(/_/g, "/") +
          "=".repeat((4 - (payloadB64.length % 4)) % 4);
        const payload = JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
        iss = payload.iss;
        console.log("iss:", payload.iss, "aud:", payload.aud);
      } catch {
        /* ignore */
      }

      let user: any;

      if (iss === "https://appleid.apple.com") {
        const claims = await verifyAppleIdToken(bearer);
        user = await upsertUser({
          provider: "apple",
          providerSub: String(claims.sub),
          email: (claims as any).email ?? undefined,
          name: undefined,
        });
      } else if (
        iss === "https://accounts.google.com" ||
        iss === "accounts.google.com"
      ) {
        const claims = await verifyGoogleIdToken(bearer);
        user = await upsertUser({
          provider: "google",
          providerSub: String(claims.sub),
          email: (claims as any).email ?? undefined,
          name: (claims as any).name ?? undefined,
        });
      } else {
        res.status(400).json({ error: "unsupported_issuer" });
        return;
      }

      const appJwt = await signAppJWT({
        sub: user._id!.toString(),
        roles: user.roles ?? ["user"],
        ver: user.tokenVersion ?? 1,
      });

      // ⬇️ mint per-login refresh token
      const { token: refreshToken, doc } = mintRefreshTokenDoc(user._id);
      await refreshTokensCollection(db).insertOne(doc);

      res.json({
        token: appJwt,
        refresh_token: refreshToken,
        user: toApiUser(user),
      });
      return;
    }

    // Else: email+password in body
    const { email, password } = req.body ?? {};
    if (typeof email === "string" && typeof password === "string") {
      const existing = await findUserByEmail(email);
      if (!existing) {
        res.status(404).json({ error: "user_not_found" });
        return;
      }

      if (!existing.passwordHash) {
        res.status(409).json({ error: "password_login_not_enabled" });
        return;
      }

      const ok = await bcrypt.compare(password, existing.passwordHash);
      if (!ok) {
        res.status(401).json({ error: "invalid_credentials" });
        return;
      }

      const appJwt = await signAppJWT({
        sub: existing._id!.toString(),
        roles: existing.roles ?? ["user"],
        ver: existing.tokenVersion ?? 1,
      });
      const { token: refreshToken, doc } = mintRefreshTokenDoc(existing._id);
      await refreshTokensCollection(db).insertOne(doc);

      res.json({
        token: appJwt,
        refresh_token: refreshToken,
        user: toApiUser(existing),
      });
      return;
    }

    res.status(400).json({ error: "no_auth_supplied" });
  } catch (err) {
    console.error("auth/session error:", err);
    res.status(401).json({ error: "invalid_token_or_credentials" });
  }
};

/** POST /api/auth/register - Dedicated registration endpoint */
const registerHandler: RequestHandler = async (req, res) => {
  try {
    const { email, password, name } = req.body ?? {};
    
    if (!email || !password) {
      res.status(400).json({ error: "email_and_password_required" });
      return;
    }

    if (typeof email !== "string" || typeof password !== "string") {
      res.status(400).json({ error: "invalid_input_format" });
      return;
    }

    if (password.length < 8 || !(/[a-z]/.test(password) && (/[A-Z]/.test(password) || /\d/.test(password) || /[^\w\s]/.test(password)))) {
      res.status(400).json({ error: "weak_password" });
      return;
    }

    const existing = await findUserByEmail(email);
    if (existing) {
      res.status(409).json({ error: "email_already_exists" });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await createUserWithPassword({ 
      email, 
      passwordHash,
      name: typeof name === "string" ? name : null
    });

    const db = await getDb();
    const appJwt = await signAppJWT({
      sub: user._id!.toString(),
      roles: user.roles ?? ["user"],
      ver: user.tokenVersion ?? 1,
    });

    const { token: refreshToken, doc } = mintRefreshTokenDoc(user._id);
    await refreshTokensCollection(db).insertOne(doc);

    res.status(201).json({
      token: appJwt,
      refresh_token: refreshToken,
      user: toApiUser(user),
    });
    return;
  } catch (err) {
    console.error("auth/register error:", err);
    res.status(500).json({ error: "registration_failed" });
    return;
  }
};

router.post("/api/auth/register", express.json(), registerHandler);
router.post("/api/auth/session", express.json(), createSession);

const refreshHandler: RequestHandler = async (req, res) => {
  try {
    const rt = String(req.body?.refresh_token || "");
    if (!rt) {
      res.status(400).json({ error: "missing_refresh_token" });
      return;
    }

    // verify + rotate (example using selector.verifier format)
    const [selector, verifier] = rt.split(".");
    if (!selector || !verifier) {
      res.status(400).json({ error: "invalid_refresh_token_format" });
      return;
    }

    const db = await getDb();
    const col = refreshTokensCollection(db);
    const doc = await col.findOne({
      selector,
      revoked: false,
      expiresAt: { $gt: new Date() },
    });
    if (!doc || !(await bcrypt.compare(verifier, doc.hash))) {
      res.status(401).json({ error: "invalid_refresh_token" });
      return;
    }

    // rotate old
    await col.updateOne(
      { _id: doc._id },
      { $set: { revoked: true, revokedAt: new Date() } }
    );

    // mint new refresh token
    const newSelector = crypto.randomUUID();
    const newVerifier = crypto.randomBytes(32).toString("base64url");
    await col.insertOne({
      selector: newSelector,
      hash: await bcrypt.hash(newVerifier, 12),
      userId: doc.userId,
      jti: crypto.randomUUID(),
      revoked: false,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30),
    });

    // issue new app JWT
    const user = await usersCollection(db).findOne({ _id: doc.userId });
    if (!user) {
      res.status(404).json({ error: "user_not_found" });
      return;
    }

    const appJwt = await signAppJWT({
      sub: String(doc.userId),
      roles: user.roles ?? ["user"],
      ver: user.tokenVersion ?? 1,
    });

    res.json({
      token: appJwt,
      refresh_token: `${newSelector}.${newVerifier}`,
    });
    return; // ✅ return void
  } catch (e) {
    console.error("auth/refresh error:", e);
    res.status(500).json({ error: "refresh_failed" });
    return;
  }
};

const resetPasswordHandler: RequestHandler = async (req, res) => {
  try {
    const { email, newPassword } = req.body ?? {};
    
    if (!email || !newPassword) {
      res.status(400).json({ error: "email_and_new_password_required" });
      return;
    }

    if (typeof email !== "string" || typeof newPassword !== "string") {
      res.status(400).json({ error: "invalid_input_format" });
      return;
    }

    if (newPassword.length < 8 || !(/[a-z]/.test(newPassword) && (/[A-Z]/.test(newPassword) || /\d/.test(newPassword) || /[^\w\s]/.test(newPassword)))) {
      res.status(400).json({ error: "weak_password" });
      return;
    }

    const user = await findUserByEmail(email);
    if (!user) {
      res.status(404).json({ error: "user_not_found" });
      return;
    }

    if (user.provider !== "password") {
      res.status(400).json({ error: "password_reset_not_available_for_this_account" });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const db = await getDb();
    await usersCollection(db).updateOne(
      { _id: user._id },
      { 
        $set: { 
          passwordHash,
          updatedAt: new Date()
        }
      }
    );

    res.json({ message: "password_reset_successful" });
    return;
  } catch (err) {
    console.error("auth/reset-password error:", err);
    res.status(500).json({ error: "password_reset_failed" });
    return;
  }
};

// ✅ Pass RequestHandler; express.json() is also a RequestHandler
router.post("/api/auth/refresh", express.json(), refreshHandler);
router.post("/api/auth/reset-password", express.json(), resetPasswordHandler);
