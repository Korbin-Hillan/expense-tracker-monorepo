// store.ts
import { getDb, usersCollection } from "./database/databaseConnection.js";
import type { Provider, User } from "./types/user.ts";

export async function upsertUser(input: {
  provider: Provider;
  providerSub?: string;
  email?: string;
  name?: string;
}) {
  const db = await getDb();
  const col = usersCollection(db);

  if (input.providerSub) {
    const bySub = await col.findOne({
      provider: input.provider,
      providerSub: input.providerSub,
    });
    if (bySub) return bySub;
  }

  if (input.email) {
    const byEmail = await col.findOne({ email: input.email });
    if (byEmail) {
      await col.updateOne(
        { _id: byEmail._id },
        {
          $set: {
            provider: input.provider,
            providerSub: input.providerSub ?? byEmail.providerSub ?? null,
            name: byEmail.name ?? input.name ?? null,
            updatedAt: new Date(),
          },
          $setOnInsert: { roles: ["user"], tokenVersion: 1 },
        }
      );
      return await col.findOne({ _id: byEmail._id });
    }
  }

  const doc: User = {
    email: input.email ?? null,
    name: input.name ?? null,
    provider: input.provider,
    providerSub: input.providerSub ?? null,
    roles: ["user"],
    tokenVersion: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const res = await col.insertOne(doc as any);
  return (await col.findOne({ _id: res.insertedId })) as User;
}

export async function findUserByEmail(email: string) {
  const db = await getDb();
  return usersCollection(db).findOne({ email });
}

export async function createUserWithPassword({
  email,
  passwordHash,
  name = null,
}: {
  email: string;
  passwordHash: string;
  name?: string | null;
}) {
  const db = await getDb();
  const col = usersCollection(db);
  const doc: User = {
    email,
    name,
    provider: "password",
    providerSub: null,
    passwordHash,
    roles: ["user"],
    tokenVersion: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const res = await col.insertOne(doc as any);
  return (await col.findOne({ _id: res.insertedId })) as User;
}
