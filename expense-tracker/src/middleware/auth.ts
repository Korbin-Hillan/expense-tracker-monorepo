import * as dotenv from "dotenv";
dotenv.config();

import { Request, Response, NextFunction } from "express";
import { jwtVerify, importSPKI } from "jose";

const APP_ISSUER = process.env.APP_JWT_ISSUER!;
const PUBLIC_PEM = process.env.APP_JWT_PUBLIC_PEM!;

console.log("🔧 Environment check:");
console.log("APP_JWT_ISSUER:", APP_ISSUER || "MISSING");
console.log("APP_JWT_PUBLIC_PEM length:", PUBLIC_PEM ? PUBLIC_PEM.length : "MISSING");

let publicKey: CryptoKey | undefined;
async function getKey() {
  if (!publicKey) publicKey = await importSPKI(PUBLIC_PEM, "RS256");
  return publicKey;
}

// ✅ return type is Promise<void>, and we don't `return res...`
export async function requireAppJWT(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    console.log("🔐 Auth middleware: Starting JWT verification");
    console.log("🌐 Expected issuer (APP_ISSUER):", APP_ISSUER);
    
    const auth = req.header("authorization") ?? "";
    const m = auth.match(/^Bearer (.+)$/i);
    if (!m) {
      console.log("❌ Auth middleware: Missing Bearer token");
      res.status(401).json({ error: "missing_bearer" });
      return;
    }

    console.log("🎫 Auth middleware: Token received:", m[1].substring(0, 50) + "...");
    
    // Decode token payload for debugging
    try {
      const parts = m[1].split('.');
      if (parts.length >= 2) {
        const payload = JSON.parse(Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - parts[1].length % 4) % 4), 'base64').toString());
        console.log("🔍 Token payload:", JSON.stringify(payload, null, 2));
      }
    } catch (e) {
      console.log("⚠️ Could not decode token payload for debugging:", e);
    }

    const key = await getKey();
    console.log("🔑 Auth middleware: Using key for verification");
    
    const { payload } = await jwtVerify(m[1], key, { issuer: APP_ISSUER });
    console.log("✅ Auth middleware: JWT verification successful");
    console.log("👤 User ID from token:", payload.sub);

    // attach user id from `sub`
    (req as any).userId = payload.sub;
    next();
  } catch (e) {
    console.log("❌ Auth middleware: JWT verification failed:", e);
    console.log("🔧 Error details:", {
      name: e.name,
      message: e.message,
      code: e.code
    });
    res.status(401).json({ error: "invalid_token" });
  }
}
