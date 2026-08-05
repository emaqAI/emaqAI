import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../utils/prisma";

const roleSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
});

export async function listRoles(_req: Request, res: Response) {
  const roles = await prisma.role.findMany({
    include: { permissions: { include: { permission: true } } },
    orderBy: { name: "asc" },
  });
  return res.json(
    roles.map((role) => ({
      id: role.id,
      name: role.name,
      description: role.description,
      permissions: role.permissions.map((rp) => rp.permission.name),
    })),
  );
}

export async function createRole(req: Request, res: Response) {
  const parsed = roleSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const existing = await prisma.role.findUnique({ where: { name: parsed.data.name } });
  if (existing) {
    return res.status(409).json({ error: "Rola o tej nazwie juz istnieje" });
  }

  const role = await prisma.role.create({ data: parsed.data });
  return res.status(201).json(role);
}

export async function deleteRole(req: Request, res: Response) {
  const role = await prisma.role.findUnique({ where: { id: req.params.id } });
  if (!role) {
    return res.status(404).json({ error: "Rola nie znaleziona" });
  }
  await prisma.role.delete({ where: { id: req.params.id } });
  return res.status(204).send();
}

const permissionAssignSchema = z.object({ permissionId: z.string().min(1) });

export async function assignPermission(req: Request, res: Response) {
  const parsed = permissionAssignSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const roleId = req.params.id;
  const { permissionId } = parsed.data;

  const [role, permission] = await Promise.all([
    prisma.role.findUnique({ where: { id: roleId } }),
    prisma.permission.findUnique({ where: { id: permissionId } }),
  ]);
  if (!role) return res.status(404).json({ error: "Rola nie znaleziona" });
  if (!permission) return res.status(404).json({ error: "Uprawnienie nie znalezione" });

  await prisma.rolePermission.upsert({
    where: { roleId_permissionId: { roleId, permissionId } },
    create: { roleId, permissionId },
    update: {},
  });

  return res.status(201).json({ roleId, permissionId });
}

export async function removePermission(req: Request, res: Response) {
  const roleId = req.params.id;
  const permissionId = req.params.permissionId;
  await prisma.rolePermission.deleteMany({ where: { roleId, permissionId } });
  return res.status(204).send();
}
