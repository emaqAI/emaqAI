import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../utils/prisma";
import { getUserPermissionNames, getUserRoleNames } from "../services/rbac.service";

export async function listUsers(_req: Request, res: Response) {
  const users = await prisma.user.findMany({
    select: { id: true, email: true, isActive: true, createdAt: true },
    orderBy: { createdAt: "asc" },
  });
  return res.json(users);
}

export async function getUser(req: Request, res: Response) {
  const user = await prisma.user.findUnique({ where: { id: req.params.id } });
  if (!user) {
    return res.status(404).json({ error: "Uzytkownik nie znaleziony" });
  }
  const roles = await getUserRoleNames(user.id);
  const permissions = await getUserPermissionNames(user.id);
  return res.json({ id: user.id, email: user.email, isActive: user.isActive, roles, permissions });
}

const setActiveSchema = z.object({ isActive: z.boolean() });

export async function setUserActive(req: Request, res: Response) {
  const parsed = setActiveSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: parsed.data.isActive },
  });
  return res.json({ id: user.id, email: user.email, isActive: user.isActive });
}

const assignRoleSchema = z.object({ roleId: z.string().min(1) });

export async function assignRole(req: Request, res: Response) {
  const parsed = assignRoleSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const userId = req.params.id;
  const { roleId } = parsed.data;

  const [user, role] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.role.findUnique({ where: { id: roleId } }),
  ]);
  if (!user) return res.status(404).json({ error: "Uzytkownik nie znaleziony" });
  if (!role) return res.status(404).json({ error: "Rola nie znaleziona" });

  await prisma.userRole.upsert({
    where: { userId_roleId: { userId, roleId } },
    create: { userId, roleId },
    update: {},
  });

  const roles = await getUserRoleNames(userId);
  return res.json({ id: userId, roles });
}

export async function removeRole(req: Request, res: Response) {
  const userId = req.params.id;
  const roleId = req.params.roleId;

  await prisma.userRole.deleteMany({ where: { userId, roleId } });

  const roles = await getUserRoleNames(userId);
  return res.json({ id: userId, roles });
}
