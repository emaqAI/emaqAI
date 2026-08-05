import { Router } from "express";
import { authenticate } from "../middleware/authenticate";
import { requirePermission } from "../middleware/authorize";
import {
  createPermission,
  deletePermission,
  listPermissions,
} from "../controllers/permissions.controller";

export const permissionsRouter = Router();

permissionsRouter.use(authenticate);

permissionsRouter.get("/", requirePermission("permissions:read"), listPermissions);
permissionsRouter.post("/", requirePermission("permissions:manage"), createPermission);
permissionsRouter.delete("/:id", requirePermission("permissions:manage"), deletePermission);
