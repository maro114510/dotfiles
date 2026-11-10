# TickTick CLI

Why this setup: [ADR](adr/ticktick-cli-pinned-official.md).

## Install

```bash
pnpm-policy.sh --check || pnpm-policy.sh --apply
chezmoi apply
mise install
mise lock --global
```

Never use `npm install -g` or `npx` for this tool.

## Log in

1. Unlock 1Password with its CLI integration enabled.
2. Run `ticktick-op.sh login` and approve in the browser.
3. Run `ticktick-op.sh status`.

The token is stored at `op://Personal/TickTick CLI/credential`.
`TICKTICK_OP_VAULT` and `TICKTICK_OP_ITEM` override the vault and item.
Never run `ticktick auth token <token>`; it puts the token in argv.

## Use

```bash
ticktick-op.sh project list --json
ticktick-op.sh task search --help
```

Exit codes: 0 success, 1 CLI or API error, 2 misuse, 3 blocked for lack of approval.

Run without a person:

- `project list|get|data|members`
- `task get|create|update|complete|completed|filter|search`
- `tag list`, `preference get`, `countdown list`

Everything else asks for a typed `yes` on the terminal, and exits 3 without one.

OpenCode rules to deny the bare command and allow the wrapper:

```jsonc
{ "action": "shell", "resource": "ticktick *", "effect": "deny" },
{ "action": "shell", "resource": "*ticktick-op.sh *", "effect": "allow" }
```

## Update

1. Read `npm view @ticktick/ticktick-cli versions time`.
2. Fetch the new tarball into an empty directory and diff its `dist/` against the pinned one.
   Check scripts, dependencies and hosts again.
3. Change the pin in `dot_config/mise/config.toml`.
4. Run `chezmoi apply`, `mise install`, `mise lock --global`.

## Roll back or remove

```bash
# Roll back: restore the previous pin, then
chezmoi apply && mise install

# Remove
mise uninstall "npm:@ticktick/ticktick-cli@0.1.15"
```

Then delete the 1Password item "TickTick CLI" and revoke the app in TickTick's account settings.
