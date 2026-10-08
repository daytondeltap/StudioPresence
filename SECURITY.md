# Security review — 2026-10-08

Reviewed fork: daytondeltap/StudioPresence. Starting commit: `0aaf5a943dbbdb416d1e2a72c3b345a6c119daba`.

## Standalone plugin addition

The new `src/standalone` variant replaces the local companion with Discord HTTPS OAuth and presence requests. Its different credential and privacy boundaries, installation instructions, tests and live-verification limits are documented in [STANDALONE.md](STANDALONE.md). It introduces no additional runtime package dependencies. Remembering OAuth credentials is off by default; optional saved tokens are not encrypted by this plugin. Discord's presence scope also grants friends-list access, although this plugin does not query friends. Direct presence access depends on the user's Discord application having Social SDK access. The companion-specific findings below still apply to the older companion variant.

## Result and scope

Manual inspection of every tracked application source file, startup script, package configuration, dependency lockfile and workflow found no evidence of a virus, credential theft, remote command execution, concealed downloader or unauthorized automatic persistence in the reviewed application code. This is a source review and dependency advisory check, not an antivirus certification. The fork had no published releases at review time.

The original dependency audit reported **22 advisories** (16 high, 5 moderate, 1 low). The updated locked dependency audit reports **zero known advisories**. These counts concern vulnerability reports, not 22 viruses. Evidence is recorded in [security/dependency-audit.json](security/dependency-audit.json).

## Changes

| Finding | Fix |
| --- | --- |
| HTTP bridge listened on all interfaces | Bind only to IPv4 loopback, 127.0.0.1:4455; update the companion plugin to match |
| Browser and DNS-rebinding requests could modify presence | Reject Origin/Sec-Fetch-Site headers, nonlocal Host, other routes, non-POST requests and non-JSON content |
| Unlimited, unvalidated input; malformed requests could clear activity or hang | Limit payloads to 16 KiB, validate supported activity fields, bound connections/in-flight operations, add request timeouts and always return an error response |
| Unhandled Discord promise failures; hidden startup could crash while accessing raw stdin | Handle RPC/login errors and only use raw stdin for a terminal |
| pkg 5.8.1 privilege-escalation advisory and obsolete Node 18 binaries | Replace with pinned @yao-pkg/pkg 6.23.0 and Node 24 targets |
| Vulnerable build utilities and transitive packages | Replace rimraf/copy-file-util with Node built-ins; patch ws to 7.5.11 and tar-fs to 2.1.4; regenerate lockfile |
| Unused optional native protocol-registration installer | Remove register-scheme from discord-rpc's dependency graph; presence uses IPC and never called this registration feature |
| Mutable workflow action tags and unnecessary install hooks | Pin action commits, use read-only workflow token permissions, disable persisted checkout credentials and dependency install scripts |
| Unsafe blanket antivirus-exclusion advice and upstream download links | Direct users to this fork's builds; document quarantine/investigation and verification limits |
| Optional Windows startup path could be parsed incorrectly | Quote the configured executable path; keep startup explicitly user-installed |

The bridge still forwards developing, testing, animating, workspace, script name/type and cursor/line-count presence, timestamps and images. CLOSE still clears presence. The three-second playtest debounce remains. Thumbnail hover text now accepts the plugin's legacy field and its corrected field. Long/control-character-containing display text is normalized to Discord's supported length rather than rejected. Startup remains optional. Build scripts emit SHA-256 checksums.

## Data and remaining boundaries

- The plugin intentionally shares workspace and script names, script type, cursor line and total line count with your local Discord client. Discord can show these to others according to activity privacy settings. No source-code text is forwarded by the reviewed activity payload.
- The plugin queries Roblox's MarketplaceService for the place name. Presence updates go to local HTTP, then Discord IPC. No Discord password or session token is required by the app.
- A program already running on your computer can still impersonate the plugin and submit valid local presence updates. Loopback and browser restrictions are not per-process authentication. Such a program can also spoof a local Discord IPC endpoint. This review does not claim to secure an already-compromised computer.
- Original iArxic release binaries, existing installations, the Roblox marketplace plugin and future upstream updates are outside this review. They were not scanned or changed. Install both the server and local plugin built from this fork.
- Third-party packages and build tool binaries remain a supply-chain trust boundary. A zero-advisory audit does not prove absence of malicious or undisclosed behavior.
- Windows builds are unsigned and macOS builds are not notarized. Antivirus/OS alerts cannot be guaranteed to disappear; keep a flagged file quarantined and investigate the specific detection instead of disabling protections.
- No antivirus engine or Windows/macOS desktop environment was available here. Windows/macOS binaries were rebuilt but not executed. Roblox Studio and a real Discord session were unavailable, so live UI integration was not verified.

## Validation and reproducible build

Local verification: TypeScript checking passed, seven bridge/security tests passed, server compilation passed, Windows/macOS/Linux executables packaged, Roblox plugin built with Rojo 7.4.4, and the Linux executable started and exited cleanly with the expected Discord-not-open message. The mock IPC roundtrip test could not run locally because this execution environment disallows Unix sockets. It runs in GitHub Actions and is required there; the compiled bundle and packaged Linux binary both have CI roundtrip checks.

With Node 24 and pnpm 9.10.0:

```sh
pnpm install --frozen-lockfile --ignore-scripts
pnpm audit
pnpm typecheck
pnpm test
pnpm run package:server
pnpm run build:client
node scripts/checksums.cjs
```

The last client build command requires the Rojo version pinned in `foreman.toml`. `Package` workflow builds and uploads the server and plugin artifacts. Use artifacts from the same successful run. The checksums establish file identity; they are not a malware test.
