import { Request, Response, NextFunction } from "express";
import { verifyToken } from "../utils/jwt";

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; email: string };
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Brak tokenu autoryzacyjnego" });
  }

  const token = header.slice("Bearer ".length);
  try {
    const payload = verifyToken(token);
    req.auth = { userId: payload.userId, email: payload.email };
    next();
  } catch {
    return res.status(401).json({ error: "Nieprawidlowy lub wygasly token" });
  }
}
