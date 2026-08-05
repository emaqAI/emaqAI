import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET ?? "dev-secret-do-not-use-in-production";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? "1h";

export interface TokenPayload {
  userId: string;
  email: string;
}

export function signToken(payload: TokenPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions);
}

export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, JWT_SECRET) as TokenPayload;
}
