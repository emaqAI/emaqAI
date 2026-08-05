import { Request, Response, NextFunction } from "express";
import { getUserPermissionNames, getUserRoleNames } from "../services/rbac.service";

export function requirePermission(...requiredPermissions: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.auth) {
      return res.status(401).json({ error: "Brak tokenu autoryzacyjnego" });
    }

    const permissions = await getUserPermissionNames(req.auth.userId);
    const hasPermission = requiredPermissions.some((p) => permissions.includes(p));

    if (!hasPermission) {
      return res.status(403).json({ error: "Brak wymaganych uprawnien" });
    }

    next();
  };
}

export function requireRole(...requiredRoles: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.auth) {
      return res.status(401).json({ error: "Brak tokenu autoryzacyjnego" });
    }

    const roles = await getUserRoleNames(req.auth.userId);
    const hasRole = requiredRoles.some((r) => roles.includes(r));

    if (!hasRole) {
      return res.status(403).json({ error: "Brak wymaganej roli" });
    }

    next();
  };
}
