import { Client } from "discord-rpc";
import chalk from "chalk";
import { createBridge, SERVER_HOST, SERVER_PORT } from "./bridge";

const CLIENT_ID = "1028311936854675458";
const client = new Client({ transport: "ipc" });
const server = createBridge(client);
function fatal(error: unknown) {
  console.error(chalk.red("StudioPresence failed:"), error);
  // Hidden startup and redirected stdin are not TTYs.
  if (process.stdin.isTTY && typeof process.stdin.setRawMode === "function") {
    console.log("\nPress any key to exit...");
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.once("data", () => process.exit(1));
  } else process.exit(1);
}
process.on("uncaughtException", fatal);
process.on("unhandledRejection", fatal);
server.on("error", fatal);
async function start() {
  try { await client.login({ clientId: CLIENT_ID }); }
  catch {
    console.error(chalk.red("StudioPresence failed to start (Is Discord open?)"));
    await client.destroy().catch(() => undefined);
    process.exitCode = 1;
    return;
  }
  server.listen(SERVER_PORT, SERVER_HOST, () => {
    console.log(chalk.green("StudioPresence Started!"));
    console.log(chalk.yellow("Do not see the activity? Check your activity privacy on Discord!"));
  });
}
void start();
