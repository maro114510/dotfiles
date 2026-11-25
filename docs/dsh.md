# DSH configuration

`chezmoi apply` reproduces the DSH runtime, the shared plugin baseline, and the shared policy.
The runtime tracks the newest published release instead of a pin, and a LaunchAgent keeps the Web GUI running on the release it was last moved to.
Credentials, sessions, and other runtime state stay out of this repository.

## Ownership

| Path | Owner |
|---|---|
| `~/.dsh/cordis.patch.yml` | dotfiles |
| `~/.dsh/AGENTS.md` | dotfiles |
| `~/.dsh/profiles/web/package.json` | dotfiles merges the managed part, DSH owns the rest |
| `~/.dsh/profiles/web/cordis.patch.yml` | DSH |
| `~/.dsh/profiles/web/pnpm-lock.yaml`, `pnpm-workspace.yaml` | DSH |
| `~/.dsh/.credentials.yaml`, `plugins/`, `storages/`, `sessions/`, `logs/`, `attachments/`, `profiles/web/.dsh-market/`, `profiles/web/.plugin-manager/` | DSH, never tracked |
| `~/.local/bin/dsh` | dotfiles |
| `~/.local/bin/dsh-web-supervisor` | dotfiles |
| `~/.local/bin/dsh-web-login` | dotfiles |
| `~/Library/LaunchAgents/local.dsh-web.plist` | dotfiles |
| `~/Library/LaunchAgents/local.dsh-web-login.plist` | dotfiles |
| `~/.dsh/web-launch.conf` | the machine, never tracked |
| `~/.local/state/dsh/`, `~/.local/state/dsh-web/` | runtime state, never tracked |

## How the layers combine

- DSH applies the bundles, then the profile patch, then the home patch, so a home patch entry wins.
- A patch entry replaces the whole configuration of its target, so each entry restates every setting it keeps.
- The Web settings form refuses to save a setting that the home patch overrides.
- The home patch applies to every profile, so the entry for a plugin that a profile lacks only logs a warning.

## Workflows

| Change | How |
|---|---|
| Add a plugin on every Mac | Add the package to `modify_private_package.json` in `private_dot_dsh/profiles/web`, then apply |
| Try a plugin on one Mac | Install it from the DSH UI; it stays as a local addition |
| Change a shared setting | Edit `private_dot_dsh/cordis.patch.yml`, then apply |
| Change a machine-local setting | Change it in the DSH UI; it stays in the profile patch |
| Restore a new Mac | Follow [setup.md](setup.md), run `chezmoi apply`, then start `dsh web` |
| Keep DSH newest | Run `dsh-web-supervisor takeover` when you want it. A manual `dsh` resolves the newest published release at each start, skipping alpha releases because plugins such as `dsh-ops` reject them, while the LaunchAgent keeps the release it recorded |
| Move the Web GUI to the newest release | Run `dsh-web-supervisor takeover` from outside the session. It records the newest release, stops the running server, loads the LaunchAgent, and starts it. `DSH_VERSION=<version> dsh-web-supervisor takeover` records that release instead, and refuses one that failed in the last six hours until its marker in `~/.local/state/dsh/failing/` is removed. Before recording, it warns when the release would skip a profile bundle for a version mismatch, using a `dsh web --dump-config` dry run. After the restart it reports every skipped bundle and disabled plugin row from `server.log`; neither stops the takeover |
| Change the tested plugin versions | Edit the dependency versions in `modify_private_package.json`, then apply |

## Login gateway

A device with no cookie cannot open the Web GUI, because the process token changes at every start and the URL is not stored anywhere a person could read it without the Mac. `dsh-web-login` closes that gap without a new secret: Tailscale Serve forwards each tailnet request to it and puts the caller's login in `Tailscale-User-Login`, dropping any copy a client sent. A request from the one allowed login gets a redirect to the current token URL in `~/.local/state/dsh-web/url`, and the Web GUI turns that into its usual cookie. Any other login, or none, gets 403.

Add the allowed login to `~/.dsh/web-launch.conf`, then load the agent and publish the port:

```sh
LOGIN_ALLOWED_USER=<your Tailscale login>
LOGIN_PORT=3081
```

```sh
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/local.dsh-web-login.plist
tailscale serve --bg --https=10000 http://127.0.0.1:3081
```

Open `https://<host>:10000/` on the device. To remove it, run `tailscale serve --https=10000 off` and `launchctl bootout "gui/$(id -u)/local.dsh-web-login"`.

- The gateway listens on loopback only, so the allowed login is decided by Tailscale Serve and not by the caller.
- Never expose the gateway with `tailscale funnel`, and never forward it from another proxy that lets a client set `Tailscale-User-Login`. Either lets anyone claim the allowed login.
- The gateway reads the URL file at each request, so a restart of the server needs no change here.
- A device the tailnet marks with a tag sends no login header and is refused.
- The log `~/.local/state/dsh-web/login.log` never holds the token URL.

## Notion server

- The patch defines the Notion MCP server as disabled, because an unused server adds tool definitions to every request.
- A profile patch that defines the same id as well produces two entries, so remove the profile copy after the first apply.

## Not shared

- Web UI preferences such as language, transcript view, and dismissed notices.
- The scheduled preset, which mounts a plugin from a local repository.
- The `headless` profile and any other profile than `web`.
- The managed plugin versions, which stay at the last set tested against the runtime.

## Risks

- The shared policy sets approval `never` with full access, so every restored Mac inherits it.
- The newest release is a prerelease, so a release may regress. The supervisor marks a release that fails its health check, records the last good one, and the next restart runs it.
- The managed plugin versions can lag the runtime. A plugin that rejects the runtime fails the start, and the supervisor rolls back.
- The first restore needs network access for `npx` and `pnpm`. A failed install prints a message and the apply still succeeds, so run `dsh plugin --profile web install` again before `dsh web`.
- The home patch applies to every profile, so a Notion server that someone enables is defined in profiles that did not load it before.
- The home patch sets the Claude prompt cache to one hour. A one-hour cache write costs 2 times the base input price instead of 1.25 times, and a read costs the same, so a session that never pauses past five minutes pays more for its writes. Whether it lowers the subscription quota is not established.
- The `llm-subscriptions` entry replaces the plugin's whole configuration, so a setting added to it later must restate every other setting that the plugin should keep.
- A UI change to a setting that the home patch overrides is refused, and a change to a managed dependency or bundle is restored by the next apply.
- Local additions are preserved, but their transitive versions can differ between Macs.

## Web GUI runtime

`~/Library/LaunchAgents/local.dsh-web.plist` runs `dsh-web-supervisor run`, which starts `dsh web` on the release recorded in `~/.local/state/dsh-web/version`. A first start records the newest release. launchd restarts it on the same release when it exits and after login, and passes its stop request to the server. The LaunchAgent starts with the next login; run `dsh-web-supervisor takeover` to move the current session under it now.

Machine-local flags live in `~/.dsh/web-launch.conf`, which this repository never tracks. The file and every key are optional; without `PUBLIC_URL` and `TRUSTED_HOST` the server listens on loopback only:

```sh
PORT=3080
PUBLIC_URL=https://<host>/
TRUSTED_HOST=<host>
PATCH_FILE=/Users/<you>/.dsh/web-extra.patch.yml
```

- `dsh-web-supervisor status` shows the recorded release, the resolved newest release, the last good release, the listener and the health code.
- `dsh-web-supervisor check` prints the resolved and last good releases only.
- The server writes its process-token URL to `~/.local/state/dsh-web/url`. The browser cookie stays valid across restarts, so a reload recovers an authenticated page.
- The state directory `~/.local/state/dsh-web` is mode 700 and its logs are mode 600, because `server.log` carries the process-token URL.
- After each start, including a restart by launchd, `launchd.log` names every skipped bundle and disabled plugin row that the server wrote to `server.log` during that start, with the version range that excluded it. The warning never stops the server.
- Every exit of the server adds one line to `~/.local/state/dsh-web/launchd.log` with its status, and the signal name when the status is above 128. A stop that launchd or a person requested is marked `stopped on request`. A server killed by SIGKILL leaves status 137 there.
- A release that fails the health check is marked in `~/.local/state/dsh/failing/` and skipped for six hours, while the last good release runs.
