import { Router } from "express";
import { authenticate } from "../middleware/authenticate";
import { requirePermission } from "../middleware/authorize";
import {
  assignRole,
  getUser,
  listUsers,
  removeRole,
  setUserActive,
} from "../controllers/users.controller";

export const usersRouter = Router();

usersRouter.use(authenticate);

usersRouter.get("/", requirePermission("users:read"), listUsers);
usersRouter.get("/:id", requirePermission("users:read"), getUser);
usersRouter.patch("/:id/active", requirePermission("users:manage"), setUserActive);
usersRouter.post("/:id/roles", requirePermission("users:manage"), assignRole);
usersRouter.delete("/:id/roles/:roleId", requirePermission("users:manage"), removeRole);
