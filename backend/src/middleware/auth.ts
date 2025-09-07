import * as dotenv from "dotenv";
dotenv.config();

import { Request, Response, NextFunction } from "express";
import { jwtVerify, importSPKI } from "jose";

const APP_ISSUER = process.env.APP_JWT_ISSUER!;
const PUBLIC_PEM = process.env.APP_JWT_PUBLIC_PEM!;

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
    const auth = req.header("authorization") ?? "";
    const m = auth.match(/^Bearer (.+)$/i);
    if (!m) {
      res.status(401).json({ error: "missing_bearer" });
      return;
    }

    const key = await getKey();
    const { payload } = await jwtVerify(m[1], key, { issuer: APP_ISSUER });

    // attach user id from `sub`
    (req as any).userId = payload.sub;
    next();
  } catch (e) {
    console.error("JWT verification failed:", e);
    res.status(401).json({ error: "invalid_token" });
  }
}
