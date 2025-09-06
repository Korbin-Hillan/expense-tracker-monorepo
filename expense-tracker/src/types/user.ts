import { ObjectId } from "mongodb";

export type Provider = "apple" | "google" | "password";

export interface User {
  _id?: ObjectId;
  provider: Provider;
  providerSub?: string | null;
  name?: string | null;
  email?: string | null;
  avatarUrl?: string | null;
  passwordHash?: string | null;
  roles?: string[];
  tokenVersion?: number;
  timezone?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiUser {
  id: string;
  name?: string | null;
  email?: string | null;
  avatarUrl?: string | null;
  provider?: Provider | null;
  roles?: string[];
  timezone?: string | null;
}

export function toApiUser(user: User): ApiUser {
  return {
    id: String(user._id!),
    name: user.name ?? null,
    email: user.email ?? null,
    avatarUrl: user.avatarUrl ?? null,
    provider: user.provider ?? null,
    roles: user.roles ?? ["user"],
    timezone: user.timezone ?? null,
  };
}
