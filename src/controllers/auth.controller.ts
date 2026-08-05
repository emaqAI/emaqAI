import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { prisma } from "../utils/prisma";
import { signToken } from "../utils/jwt";
import { getUserPermissionNames, getUserRoleNames } from "../services/rbac.service";

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, "Haslo musi miec co najmniej 8 znakow"),
});

export async function register(req: Request, res: Response) {
  const parsed = credentialsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: "Uzytkownik z tym adresem email juz istnieje" });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const defaultRole = await prisma.role.findUnique({ where: { name: "user" } });

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      roles: defaultRole ? { create: [{ roleId: defaultRole.id }] } : undefined,
    },
  });

  return res.status(201).json({ id: user.id, email: user.email });
}

export async function login(req: Request, res: Response) {
  const parsed = credentialsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !user.isActive) {
    return res.status(401).json({ error: "Nieprawidlowe dane logowania" });
  }

  const passwordMatches = await bcrypt.compare(password, user.passwordHash);
  if (!passwordMatches) {
    return res.status(401).json({ error: "Nieprawidlowe dane logowania" });
  }

  const token = signToken({ userId: user.id, email: user.email });
  const roles = await getUserRoleNames(user.id);
  const permissions = await getUserPermissionNames(user.id);

  return res.json({ token, user: { id: user.id, email: user.email, roles, permissions } });
}

export async function me(req: Request, res: Response) {
  const userId = req.auth!.userId;
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    return res.status(404).json({ error: "Uzytkownik nie znaleziony" });
  }
  const roles = await getUserRoleNames(user.id);
  const permissions = await getUserPermissionNames(user.id);
  return res.json({ id: user.id, email: user.email, roles, permissions });
}
