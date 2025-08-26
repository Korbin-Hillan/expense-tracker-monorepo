import { ObjectId } from "mongodb";

export interface RefreshToken {
  _id?: ObjectId;
  selector: string; // lookup key
  hash: string; // bcrypt hash of verifier
  userId: ObjectId; // reference to User._id
  jti: string; // unique ID for token tracking
  revoked: boolean;
  createdAt: Date;
  revokedAt?: Date;
  expiresAt: Date;
}
