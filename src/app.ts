import express from "express";
import cors from "cors";
import helmet from "helmet";
import { authRouter } from "./routes/auth.routes";
import { usersRouter } from "./routes/users.routes";
import { rolesRouter } from "./routes/roles.routes";
import { permissionsRouter } from "./routes/permissions.routes";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => res.json({ status: "ok" }));

  app.use("/auth", authRouter);
  app.use("/users", usersRouter);
  app.use("/roles", rolesRouter);
  app.use("/permissions", permissionsRouter);

  app.use((_req, res) => res.status(404).json({ error: "Nie znaleziono zasobu" }));

  return app;
}
