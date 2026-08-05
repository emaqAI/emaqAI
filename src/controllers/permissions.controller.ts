import { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../utils/prisma";

const permissionSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
});

export async function listPermissions(_req: Request, res: Response) {
  const permissions = await prisma.permission.findMany({ orderBy: { name: "asc" } });
  return res.json(permissions);
}

export async function createPermission(req: Request, res: Response) {
  const parsed = permissionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const existing = await prisma.permission.findUnique({ where: { name: parsed.data.name } });
  if (existing) {
    return res.status(409).json({ error: "Uprawnienie o tej nazwie juz istnieje" });
  }

  const permission = await prisma.permission.create({ data: parsed.data });
  return res.status(201).json(permission);
}

export async function deletePermission(req: Request, res: Response) {
  const permission = await prisma.permission.findUnique({ where: { id: req.params.id } });
  if (!permission) {
    return res.status(404).json({ error: "Uprawnienie nie znalezione" });
  }
  await prisma.permission.delete({ where: { id: req.params.id } });
  return res.status(204).send();
}
