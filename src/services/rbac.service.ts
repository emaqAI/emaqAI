import { prisma } from "../utils/prisma";

export async function getUserRoleNames(userId: string): Promise<string[]> {
  const userRoles = await prisma.userRole.findMany({
    where: { userId },
    include: { role: true },
  });
  return userRoles.map((ur) => ur.role.name);
}

export async function getUserPermissionNames(userId: string): Promise<string[]> {
  const userRoles = await prisma.userRole.findMany({
    where: { userId },
    include: { role: { include: { permissions: { include: { permission: true } } } } },
  });

  const permissions = new Set<string>();
  for (const userRole of userRoles) {
    for (const rolePermission of userRole.role.permissions) {
      permissions.add(rolePermission.permission.name);
    }
  }
  return [...permissions];
}
