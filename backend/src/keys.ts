import { importPKCS8, SignJWT, exportJWK, JWTPayload } from "jose";
import { createPublicKey } from "crypto";

const PRIV_PEM = process.env.APP_JWT_PRIVATE_PEM!;
const PUB_PEM = process.env.APP_JWT_PUBLIC_PEM!;
const KID = process.env.APP_JWT_KID || "app-key-1";
const ISSUER = process.env.APP_JWT_ISSUER!; // validated at startup

export async function signAppJWT(payload: JWTPayload) {
  const key = await importPKCS8(PRIV_PEM, "RS256");
  return await new SignJWT(payload)
    .setProtectedHeader({ alg: "RS256", kid: KID })
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime("15m")
    .sign(key);
}

export async function getJWKS() {
  const pubKey = createPublicKey(PUB_PEM);
  const jwk = await exportJWK(pubKey);

  return { keys: [{ ...jwk, kid: KID, alg: "RS256", use: "sig" }] };
}
