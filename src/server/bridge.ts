import http from "node:http";
import type { Presence } from "discord-rpc";

export const SERVER_PORT = 4455;
export const SERVER_HOST = "127.0.0.1";
export const MAX_BODY_BYTES = 16 * 1024;
type RPC = {
  setActivity(activity: Presence): Promise<unknown>;
  clearActivity(): Promise<unknown>;
};
function object(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function text(value: unknown, optional = false): string | undefined {
  if (optional && value === undefined) return undefined;
  if (typeof value !== "string" || Array.from(value).length > 128 || /[\x00-\x1f\x7f]/.test(value)) {
    throw new Error("Invalid activity text");
  }
  return value;
}
export function parseActivity(body: unknown): Presence | null {
  if (!object(body)) throw new Error("Invalid request");
  // The plugin sends CLOSE at the top level, with no activity.
  if (body.updateType === "CLOSE") return null;
  if (body.updateType !== "SET_ACTIVITY" || !object(body.activity)) throw new Error("Invalid update type");
  const a = body.activity;
  if (!object(a.timestamps) || !object(a.assets)) throw new Error("Missing activity fields");
  const start = a.timestamps.start;
  if (typeof start !== "number" || !Number.isSafeInteger(start) || start < 0 || start > 2147483647000) {
    throw new Error("Invalid timestamp");
  }
  // Copy supported fields only. Never evaluate or execute input.
  return {
    details: text(a.details), state: text(a.state, true), startTimestamp: start,
    largeImageText: text(a.assets.large_text, true), largeImageKey: text(a.assets.large_image, true),
    smallImageText: text(a.assets.small_text ?? a.assets.small_image_key, true),
    smallImageKey: text(a.assets.small_image, true),
  };
}
export function createBridge(client: RPC, port = SERVER_PORT) {
  let lastTesting = 0;
  let activeRequests = 0;
  const server = http.createServer((req, res) => {
    const reply = (status: number, message: string) => {
      if (res.writableEnded || res.destroyed) return;
      res.writeHead(status, { "Content-Type": "text/plain", "Cache-Control": "no-store" });
      res.end(message);
    };
    // Roblox sends no Origin. Reject browsers and DNS-rebinding hosts.
    if (req.headers.origin !== undefined || req.headers["sec-fetch-site"] !== undefined ||
        req.headers.host !== `${SERVER_HOST}:${port}`) {
      reply(403, "Forbidden"); req.resume(); return;
    }
    if (req.url !== "/") { reply(404, "Not found"); req.resume(); return; }
    if (req.method !== "POST") { reply(405, "POST required"); req.resume(); return; }
    if (req.headers["content-encoding"] !== undefined ||
        req.headers["content-type"]?.split(";")[0].trim().toLowerCase() !== "application/json") {
      reply(415, "JSON required"); req.resume(); return;
    }
    if (Number(req.headers["content-length"]) > MAX_BODY_BYTES) {
      reply(413, "Request too large"); req.resume(); return;
    }
    if (activeRequests >= 16) { reply(503, "Busy"); req.resume(); return; }
    activeRequests++;
    let released = false;
    const release = () => { if (!released) { released = true; activeRequests--; } };
    let bytes = 0;
    let rejected = false;
    const chunks: Buffer[] = [];
    req.on("error", release);
    req.on("aborted", release);
    req.setTimeout(5000, () => { req.destroy(); release(); });
    req.on("data", (chunk: Buffer) => {
      bytes += chunk.length;
      if (bytes > MAX_BODY_BYTES) {
        rejected = true; chunks.length = 0; reply(413, "Request too large");
      } else if (!rejected) chunks.push(chunk);
    });
    req.on("end", async () => {
      try {
        if (rejected) return;
        let activity: Presence | null;
        try { activity = parseActivity(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
        catch { reply(400, "Invalid activity"); return; }
        try {
          if (activity === null) await client.clearActivity();
          else {
            if (activity.details === "Testing") lastTesting = Date.now();
            else if (Date.now() - lastTesting < 3000) { reply(200, "SET Activity"); return; }
            await client.setActivity(activity);
          }
          reply(200, "SET Activity");
        } catch { reply(503, "Discord unavailable"); }
      } finally { release(); }
    });
  });
  server.requestTimeout = 5000;
  server.headersTimeout = 5000;
  server.keepAliveTimeout = 1000;
  server.maxConnections = 32;
  return server;
}
