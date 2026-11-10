# TickTick CLI

Official `@ticktick/ticktick-cli`, pinned to 0.1.15, installed by mise with pnpm.
Tokens live in 1Password and are injected per run by `ticktick-op.sh`.

## Decision

| Option | Distribution | Runs | Source trust | Auth | Update and removal | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| Official npm via mise and pnpm | npm tarball, 15 packages | Node 20+ | Upstream repo returns 404; tarball audited by hand | OAuth PKCE, shared public client, no secret | Pin in mise, `mise uninstall` | Adopted |
| CarterT27 Rust, Homebrew tap | Source build only, no binary release | Needs Rust | Public, no LICENSE file, one author | PKCE; own app possible; Keychain | Brew | Held back |
| avilabss Go binary | Release binary, SHA-256 on the same release | Single binary | Public, no LICENSE file | Browser cookie into `.env` | Manual | Rejected |

Held back for the Rust CLI:

- The lockfile pins crates with known advisories (rustls, rustls-webpki, tokio, quinn-proto, atty).
- Revisit only after a lockfile refresh and a LICENSE file.

## What was verified for 0.1.15

- The tarball SHA-512 matches the registry integrity value.
- The installed `dist/` and `package.json` are identical to the audited tarball.
- There are no install scripts. `prepublishOnly` does not run on install.
- No provenance attestation is published, so tarball and source cannot be tied together.
- 15 installed packages show no known advisories on OSV.
- `dist/` contacts only `api.ticktick.com`, `ticktick.com`, `developer.ticktick.com` and `localhost:8765`.
- `dist/` has no `child_process`, `eval`, or `new Function`.
- The CLI has no keychain support and no environment token.
  It reads only `~/.config/ticktick-cli/config.json`, written without a mode.
  This is why the wrapper exists.
- Error text from a 401 contains the full token. The wrapper redacts it.
- OAuth scopes are `tasks:read tasks:write`. There is no refresh token.

## Archive features

| Need | Support |
| --- | --- |
| Completed task search | `task completed` |
| Closed project flag | Shown by `project get`, read only |
| Archive or reopen command | None |
| CSV or JSON export, backup | None; use `--json` per command |

Across candidates (only the official CLI was run against a real account):

| Candidate | Completed or discarded task search | Closed project | Export |
| --- | --- | --- | --- |
| Official CLI | `task completed` (verified in code) | `closed` shown, 5 of 19 projects were closed (verified live) | None |
| CarterT27 Rust | Not checked | Not checked | Not checked |
| avilabss Go | Not checked | Not checked | Not checked |

No destructive archive operation was run.

## Install

```bash
pnpm-policy.sh --check || pnpm-policy.sh --apply
chezmoi apply
mise install
mise lock --global
mise which ticktick
```

- `pnpm-policy.sh` was not applied on the machine when this was written.
  Apply it first so a 24-hour release age and strict dependency builds hold.
- Never use `npm install -g` or `npx` for this tool.

## Authentication

1. In the 1Password app, enable the CLI integration and unlock it.
2. Run `ticktick-op.sh login`. It opens the browser for OAuth.
3. The token goes into `op://Personal/TickTick CLI/credential`.
   Override the vault and item with `TICKTICK_OP_VAULT` and `TICKTICK_OP_ITEM`.
4. Run `ticktick-op.sh status`.

Exposure of the token:

| Place | Exposed |
| --- | --- |
| argv, shell history | No |
| Environment of the CLI | No, it starts with `env -i` (HOME, PATH, LANG, TERM only) |
| Disk | A 0600 file in a 0700 temp HOME for the duration of one run |
| Output | Redacted from stderr |

Never run `ticktick auth token <token>`. It puts the token in argv.
The wrapper blocks `auth` for that reason.

## Usage

```bash
ticktick-op.sh project list --json
ticktick-op.sh task search --help
ticktick-op.sh task create --help
```

Exit codes: 0 success, 1 CLI or API error (includes 401 and 429),
2 misuse, 3 blocked for lack of human approval.

## Agent use (OpenCode, Pi)

- Call only `ticktick-op.sh` with explicit arguments.
- Allowed unattended: `project list|get|data|members`, `task get|create|update|complete|completed|filter|search`, `tag list`, `preference`, `countdown`.
- Everything else (delete, move, batch complete, project or tag changes, comments, habits, focus)
  asks for a typed `yes` on the controlling terminal.
  Without a terminal it exits 3.
- This is a guard rail, not a sandbox. An agent can still read 1Password if it can run `op`.

Example rules for OpenCode (adapt to the existing `permissions` list, last match wins):

```jsonc
{ "action": "shell", "resource": "ticktick *", "effect": "deny" },
{ "action": "shell", "resource": "*ticktick-op.sh *", "effect": "allow" }
```

- Denying the bare `ticktick` command stops an agent from bypassing the wrapper.
- Pi has no equivalent config in this repository; call the wrapper explicitly there too.
- Not yet run from OpenCode or Pi with these rules.

## Verification log (2026-11-10, official 0.1.15, one real account)

| Check | Result |
| --- | --- |
| `--version` | 0.1.15, exit 0 |
| `status` | token readable from 1Password |
| `project list --json` | 19 projects, 5 with `closed: true` |
| `task create` | Needs `--project`; created in a non-inbox project |
| `task update` | Needs `--id` as well as the argument |
| `task get` after `complete` | `status` changed 0 to 2 |
| `task delete` without a terminal | Blocked, exit 3 |
| Piped `yes` through a pseudo-terminal | Not accepted, exit 3 |
| Fake token | 401 body echoed the token; wrapper redacted it, exit 1 |
| Child environment | HOME, LANG, PATH, TERM only; HOME 0700, config 0600; no leftovers |

Not verified:

- The final delete of the test task, which a human must approve.
  The test task stayed in the account until then.
- Rate limit (429) behavior. The CLI has no special handling; it exits 1.
- Token expiry behavior beyond the 401 shape.
- Execution from OpenCode or Pi.
- `mise.lock` content. It needs `mise lock --global` on the machine after `chezmoi apply`.

## Update

1. Read `npm view @ticktick/ticktick-cli versions time`.
2. Fetch the new tarball into an empty directory.
   Compare its `dist/` with the pinned one, and check scripts, dependencies and hosts again.
3. Change the pin in `dot_config/mise/config.toml`.
4. Run `chezmoi apply`, `mise install`, `mise lock --global`, then the checks below.

## Rollback and removal

```bash
# Roll back: restore the previous pin, then
chezmoi apply && mise install

# Remove
mise uninstall "npm:@ticktick/ticktick-cli@0.1.15"
# Delete the 1Password item "TickTick CLI"
# Revoke the app at https://ticktick.com (Settings, Account, third-party access)
```

## Checks

```bash
ticktick-op.sh --version
ticktick-op.sh status
ticktick-op.sh project list --json
```

Round trip for a throwaway task, run by a human or with approval:

```bash
ticktick-op.sh task create --help
ticktick-op.sh task create ...          # note the returned ids
ticktick-op.sh task update <taskId> ...
ticktick-op.sh task complete <projectId> <taskId>
ticktick-op.sh task delete <projectId> <taskId>   # asks for yes
```
