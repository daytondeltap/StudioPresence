# StudioPresence standalone 1.0.0

A local Roblox Studio plugin that updates Discord presence directly over HTTPS. No companion executable, local server, Node installation, or external login service is needed to use it.

## Install

1. Download `StudioPresence-Standalone-1.0.0.rbxm`. Remove or disable any older StudioPresence plugin to avoid duplicate updates.
2. In Roblox Studio, open **Plugins → Plugins Folder**. Copy the `.rbxm` into that folder and restart Studio. On Windows the folder is normally `%LOCALAPPDATA%\Roblox\Plugins`.
3. Open **Plugins → StudioPresence → Presence**. If Studio requests HTTP permission, allow access to `discord.com` for this plugin.

Install the file as a local plugin; do not place it in your published game's scripts. This fork does not replace the marketplace plugin automatically.

## One-time Discord setup

1. Visit [Discord Developer Portal](https://discord.com/developers/applications) and create your own application, for example “Roblox Studio”. Copy its **Application ID** from General Information.
2. Under **OAuth2**, enable **Public Client** and save. The application must also have **Social SDK** access with presence authorization. Check its Social SDK page if Discord rejects authorization or presence requests.
3. Paste the Application ID into the plugin and click **Save application**, then **Sign in with Discord**.
4. Open the displayed `https://discord.com/activate` link in your browser, enter the displayed code and approve your application. Never enter your Discord password, account token, bot token or client secret into the plugin.
5. Keep Discord's activity sharing enabled. The plugin should display “Connected — your activity is updating”.

Discord controls availability of Social SDK access and these endpoints. If your application cannot receive presence access, a plugin-only connection cannot be guaranteed; the plugin shows the refusal instead of asking for an account token or downloading software. Application IDs are public identifiers, not secrets. Each user can use their own application without a shared authentication backend.

## Features and controls

- Developing, testing and Moon Animator activity, with the original three-second playtest debounce.
- Place and script names, script type, cursor position, total lines and elapsed time. Declining script access leaves other activity working.
- Original public artwork as a fallback; your application's same-named uploaded assets override it.
- Pause/resume, sign-in cancellation, disconnect, connection status and a text activity preview.
- Token refresh, rate-limit handling, connection retries and presence-session recovery.

## Privacy and credentials

The plugin requests `sdk.social_layer_presence`. Discord's permission includes friends-list access as well as presence. This code only calls authorization/token, application assets and presence endpoints; it does not fetch your friends list. Review Discord's consent screen before approving.

Place/script names and cursor/line counts are sent to Discord, where others may see them according to your privacy settings. Script source is read locally only when needed to count lines; source text is not sent. Requests go only to `https://discord.com/api/v10`. There is no arbitrary remote module loading, shell execution, local HTTP listener or startup installer.

**Remember sign-in is OFF by default.** Tokens remain in the current Studio session. Turning it on saves OAuth credentials in local Studio plugin settings, which are not encrypted by this plugin. Turn it off to remove the saved credentials. **Disconnect and forget sign-in** clears local credentials and attempts to clear presence and revoke the refresh grant. If the network is unavailable, remove the application under Discord **User Settings → Authorized Apps** to revoke it yourself. Unloading also attempts to clear activity; an unreachable presence session can remain until Discord expires it (approximately 20 minutes).

## Verification and build

The three pure modules pass Luau analysis; all four source files compile. Fourteen core tests cover activity fields, privacy, authorization, session rotation, refresh, retries, pause and revocation. A separate Studio fixture executes the actual plugin entry point and exercises setup, device sign-in, playtest activity, pause, credential persistence and disconnect. These are mocked tests, not a real Studio/Discord integration test. Live authorization, visual layout and artwork rendering require verification in Studio with your own Discord application. No antivirus certification is claimed.

For maintainers only (users do not need these tools):

```sh
node scripts/test-standalone.cjs /path/to/luau
rojo build standalone.project.json -o release/StudioPresence-Standalone-1.0.0.rbxm
```

GitHub Actions pins the Luau download checksum and builds the standalone artifact alongside the existing companion variant.
