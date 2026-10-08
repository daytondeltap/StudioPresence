const { readdirSync, readFileSync, writeFileSync } = require("node:fs");
const { createHash } = require("node:crypto");
const files = readdirSync("release").filter(name => name !== "SHA256SUMS.txt").sort();
writeFileSync("release/SHA256SUMS.txt", files.map(name =>
  `${createHash("sha256").update(readFileSync(`release/${name}`)).digest("hex")}  ${name}`
).join("\n") + "\n");
