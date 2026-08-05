import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import request from "supertest";

const TEST_DB = path.join(__dirname, "test.db");

beforeAll(() => {
  process.env.DATABASE_URL = `file:${TEST_DB}`;
  process.env.JWT_SECRET = "test-secret";
  if (fs.existsSync(TEST_DB)) fs.unlinkSync(TEST_DB);
  execSync("npx prisma migrate deploy", { stdio: "inherit" });
});

afterAll(() => {
  if (fs.existsSync(TEST_DB)) fs.unlinkSync(TEST_DB);
});

describe("system kontroli dostepu (RBAC)", () => {
  it("pozwala zarejestrowac i zalogowac uzytkownika", async () => {
    const { createApp } = await import("../app");
    const app = createApp();

    const registerRes = await request(app)
      .post("/auth/register")
      .send({ email: "test@example.com", password: "Password123!" });
    expect(registerRes.status).toBe(201);

    const loginRes = await request(app)
      .post("/auth/login")
      .send({ email: "test@example.com", password: "Password123!" });
    expect(loginRes.status).toBe(200);
    expect(loginRes.body.token).toBeDefined();
  });

  it("odrzuca dostep bez tokenu", async () => {
    const { createApp } = await import("../app");
    const app = createApp();
    const res = await request(app).get("/users");
    expect(res.status).toBe(401);
  });

  it("odrzuca dostep bez wymaganego uprawnienia", async () => {
    const { createApp } = await import("../app");
    const app = createApp();

    await request(app)
      .post("/auth/register")
      .send({ email: "noperm@example.com", password: "Password123!" });
    const loginRes = await request(app)
      .post("/auth/login")
      .send({ email: "noperm@example.com", password: "Password123!" });

    const res = await request(app)
      .get("/users")
      .set("Authorization", `Bearer ${loginRes.body.token}`);
    expect(res.status).toBe(403);
  });

  it("odrzuca logowanie z blednym haslem", async () => {
    const { createApp } = await import("../app");
    const app = createApp();

    await request(app)
      .post("/auth/register")
      .send({ email: "wrongpass@example.com", password: "Password123!" });

    const res = await request(app)
      .post("/auth/login")
      .send({ email: "wrongpass@example.com", password: "ZlaHaslo!" });
    expect(res.status).toBe(401);
  });
});
