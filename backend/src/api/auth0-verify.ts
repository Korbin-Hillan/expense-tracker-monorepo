import "dotenv/config";
import { createRemoteJWKSet, jwtVerify } from "jose";

const APPLE_ISS = "https://appleid.apple.com";
const APPLE_JWKS = createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys")
);
const YOUR_IOS_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "com.korbinhillan.IOS-expense-tracker";

export async function verifyAppleIdToken(idToken: string) {
  const { payload } = await jwtVerify(idToken, APPLE_JWKS, {
    issuer: APPLE_ISS,
    audience: YOUR_IOS_BUNDLE_ID, // Apple’s aud is your bundleId / clientId
  });
  return payload; // contains sub, email (sometimes only first time), etc.
}

const GOOGLE_ISS = new Set([
  "https://accounts.google.com",
  "accounts.google.com",
]);
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs")
);
const GOOGLE_IOS_CLIENT_ID =
  process.env.GOOGLE_IOS_CLIENT_ID ||
  "900568024097-fpr7jr6l41lpk89bk68skt054489jrr5.apps.googleusercontent.com";
const GOOGLE_WEB_CLIENT_ID = process.env.GOOGLE_WEB_CLIENT_ID;

export async function verifyGoogleIdToken(idToken: string) {
  const allowedAudiences = [GOOGLE_IOS_CLIENT_ID, GOOGLE_WEB_CLIENT_ID].filter(
    (v): v is string => Boolean(v)
  );
  const { payload } = await jwtVerify(idToken, GOOGLE_JWKS, {
    audience: allowedAudiences.length === 1 ? allowedAudiences[0] : allowedAudiences,
  });
  if (!GOOGLE_ISS.has(String(payload.iss))) throw new Error("bad_issuer");
  return payload;
}
