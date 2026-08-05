import "dotenv/config";
import { createApp } from "./app";

const port = process.env.PORT ? Number(process.env.PORT) : 3000;

const app = createApp();

app.listen(port, () => {
  console.log(`System kontroli dostepu nasluchuje na porcie ${port}`);
});
