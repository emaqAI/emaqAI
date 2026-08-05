import "dotenv/config";
import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const PERMISSIONS = [
  { name: "users:read", description: "Przegladanie uzytkownikow" },
  { name: "users:manage", description: "Zarzadzanie uzytkownikami i ich rolami" },
  { name: "roles:read", description: "Przegladanie rol" },
  { name: "roles:manage", description: "Zarzadzanie rolami i ich uprawnieniami" },
  { name: "permissions:read", description: "Przegladanie uprawnien" },
  { name: "permissions:manage", description: "Zarzadzanie uprawnieniami" },
];

async function main() {
  for (const permission of PERMISSIONS) {
    await prisma.permission.upsert({
      where: { name: permission.name },
      create: permission,
      update: {},
    });
  }

  const userRole = await prisma.role.upsert({
    where: { name: "user" },
    create: { name: "user", description: "Standardowy uzytkownik bez uprawnien administracyjnych" },
    update: {},
  });

  const adminRole = await prisma.role.upsert({
    where: { name: "admin" },
    create: { name: "admin", description: "Pelny dostep do systemu kontroli" },
    update: {},
  });

  const allPermissions = await prisma.permission.findMany();
  for (const permission of allPermissions) {
    await prisma.rolePermission.upsert({
      where: { roleId_permissionId: { roleId: adminRole.id, permissionId: permission.id } },
      create: { roleId: adminRole.id, permissionId: permission.id },
      update: {},
    });
  }

  const adminEmail = process.env.SEED_ADMIN_EMAIL ?? "admin@emaqai.local";
  const adminPassword = process.env.SEED_ADMIN_PASSWORD ?? "ChangeMe123!";
  const passwordHash = await bcrypt.hash(adminPassword, 10);

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    create: { email: adminEmail, passwordHash },
    update: {},
  });

  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: admin.id, roleId: adminRole.id } },
    create: { userId: admin.id, roleId: adminRole.id },
    update: {},
  });

  console.log(`Seed zakonczony. Konto admina: ${adminEmail} / ${adminPassword}`);
  console.log(`Utworzono role: ${userRole.name}, ${adminRole.name}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
