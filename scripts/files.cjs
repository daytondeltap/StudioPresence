const { rmSync, mkdirSync, copyFileSync } = require("node:fs");
switch (process.argv[2]) {
  case "clean-server": rmSync("dist/server", { recursive: true, force: true }); break;
  case "clean-release": rmSync("release", { recursive: true, force: true }); break;
  case "copy-vbs":
    mkdirSync("release", { recursive: true });
    copyFileSync("src/server/startup.vbs", "release/startup.vbs");
    break;
  default: throw new Error("Unknown build file operation");
}
