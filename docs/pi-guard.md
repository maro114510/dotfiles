# Pi guard extension

Source: `dot_pi/agent/extensions/guard.ts`, applied to `~/.pi/agent/extensions/guard.ts`.
Pi loads it in every project; no setting enables it.

## What it does

| Tool | Target | Result |
|---|---|---|
| `read` | `.env*`, `*.pem`, `*.key`, `*id_rsa`, `*id_ed25519`, `*credentials.json`, anything under `.ssh/` or `.aws/` | Blocked |
| `read` | `*.env.example`, `*.env.sample`, `*.env.template` | Allowed |
| `write`, `edit` | `.env*`, anything under `.ssh/` or `.aws/` | Blocked |
| `bash` | `sudo`, recursive `rm`, `git push` with force or delete, `git reset --hard`, `gh ... delete`, `gh api` with `DELETE` | Asks in the TUI; blocked on refusal and when there is no UI |

- A path is checked as written, resolved against the working directory, and through its symlink target.
- These are the major patterns of `dot_config/opencode/opencode.jsonc`, not its full list.

## Operational rules

- Pi has no security boundary.
  - Pi runs every tool with the permissions of its user and asks before no tool call.
  - The guard reduces mistakes; it does not stop a hostile model.
- Run Pi only in trusted repositories.
  - `AGENTS.md`, `CLAUDE.md`, and file contents load regardless of project trust and can steer the model.
  - Decline project trust for a repository you did not write, so its `.pi/extensions` never load.
- Treat the guard as one layer.
  - Keep credentials out of the files Pi can reach.
  - Prefer short-lived credentials.
  - For untrusted work, run Pi inside a container or sandbox.
- Restore the guard with `chezmoi apply`.
  - An extension runs inside the Pi process, so the model can rewrite this file through `bash`.
  - `chezmoi diff ~/.pi` shows a tampered copy; `chezmoi apply` restores it.
- Change the rules in the source, never in `~/.pi`.

## Limits of the `tool_call` hook

- It sees only the arguments of a tool call, never what the call does.
- It covers only `read`, `write`, `edit`, and `bash`.
  - `grep`, `find`, `ls`, and tools that other extensions or MCP servers add are not checked.
- A later extension can rewrite a call's arguments after the guard has checked them.

## Known bypasses

| Bypass | Example |
|---|---|
| Reading a secret through `bash` | `cat`, `grep`, or `cp` on a secret file |
| Writing a secret location through `bash` | A redirect into `~/.ssh/config` |
| A command the patterns cannot see | `bash -c "$CMD"` with the command in a variable, aliases, `eval` of an encoded string, or a script file |
| An unlisted destructive command | `git clean`, `git checkout -- .`, `git branch -D` |
| An unlisted secret file | A token in a file whose name matches no pattern |

## Verify

```bash
CHEZMOI="$(command -v chezmoi)" bats .github/testdata/pi-guard-extension.bats
```

Manual checks in a Pi session:

- Reading `.env` is blocked; reading `.env.example` works.
- Writing `~/.ssh/config` is blocked.
- `git reset --hard` asks, and refusing blocks it.
- Editing `~/.pi/agent/extensions/guard.ts`, then `chezmoi apply`, restores it.
