import "dotenv/config";
import { MongoClient, Db, Collection } from "mongodb";
import type { User } from "../types/user.ts";
import type { RefreshToken } from "../types/RefreshToken.ts";

const uri = process.env.MONGODB_URI;
if (!uri) {
  throw new Error("MONGODB_URI is not defined in environment variables");
}

const dbName = process.env.DB_NAME || "expense_tracker";

const client = new MongoClient(uri);
let db: Db;

export async function getDb(): Promise<Db> {
  if (!db) {
    await client.connect();
    db = client.db(dbName);
    await ensureIndexes(db);
  }
  return db;
}

export function refreshTokensCollection(db: Db): Collection<RefreshToken> {
  return db.collection<RefreshToken>("refresh_tokens");
}

async function ensureIndexes(db: Db) {
  const users = db.collection<User>("users");
  await users.createIndex(
    { provider: 1, providerSub: 1 },
    {
      unique: true,
      name: "uniq_provider_sub",
      partialFilterExpression: { providerSub: { $type: "string" } },
    }
  );
  await users.createIndex({ email: 1 }, { unique: false, sparse: true });

  const refresh = db.collection<RefreshToken>("refresh_tokens");
  await refresh.createIndex(
    { selector: 1 },
    { unique: true, name: "uniq_selector" }
  );
  await refresh.createIndex({ userId: 1 });
  // TTL index to auto-expire old refresh tokens
  try {
    await refresh.createIndex(
      { expiresAt: 1 },
      { name: "ttl_expiresAt", expireAfterSeconds: 0 }
    );
  } catch (e) {
    // ignore if exists in another form
  }
}

export function usersCollection(db: Db): Collection<User> {
  return db.collection<User>("users");
}
