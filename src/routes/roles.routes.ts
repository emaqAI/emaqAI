import { Router } from "express";
import { authenticate } from "../middleware/authenticate";
import { requirePermission } from "../middleware/authorize";
import {
  assignPermission,
  createRole,
  deleteRole,
  listRoles,
  removePermission,
} from "../controllers/roles.controller";

export const rolesRouter = Router();

rolesRouter.use(authenticate);

rolesRouter.get("/", requirePermission("roles:read"), listRoles);
rolesRouter.post("/", requirePermission("roles:manage"), createRole);
rolesRouter.delete("/:id", requirePermission("roles:manage"), deleteRole);
rolesRouter.post("/:id/permissions", requirePermission("roles:manage"), assignPermission);
rolesRouter.delete("/:id/permissions/:permissionId", requirePermission("roles:manage"), removePermission);
