# npm global to pnpm/mise migration (macOS)

This is a **review-first** migration. Applying chezmoi does NOT uninstall anything. The repository cannot know which global packages are installed on your current computer.

## Ownership

| Scope | Declarative owner | Action |
| --- | --- | --- |
| Node runtime | mise | Keep node in `~/.config/mise/config.toml` |
| pnpm runtime | mise | Pin pnpm major 12 |
| npm-distributed global CLIs | mise `npm:` entries | `[settings] npm.package_manager = "pnpm"` |
| Project dependencies | Each project's package.json/lockfile | Use pnpm per project only after compatibility checks |
| Raycast memo-search | Bun | Leave as-is |
| OpenCode plugins | OpenCode plugin manager | Not controlled by pnpm settings |
| GUI/macOS utilities | Homebrew | Leave as-is |

### 1. Capture a local inventory (read only)

```bash
node-global-audit.sh | tee "$HOME/npm-global-inventory.txt"
type -a npm node pnpm mise
mise ls --global
```

This reports global npm packages in PATH and common mise/nvm/asdf/nodenv/volta installations, grouped by npm prefix. This is *not* a complete filesystem scan. If you use alternative Node managers or custom prefixes, inspect those explicitly. Keep the inventory **out of Git**: paths and package names may be sensitive.

**Important:** The reported `npm:` entries are *candidates*, not a ready-to-paste manifest. Libraries without CLI binaries do not belong in mise; move them into project dependencies if needed. Neither npm nor its bundled corepack belongs in this list. Existing npm-installed global packages remain untouched.

### 2. Bootstrap pnpm, then configure security controls

```bash
mise install node pnpm
pnpm-policy.sh --apply
pnpm-policy.sh --check
pnpm --version
mise settings get npm.package_manager
```

The policy helper updates four **non-secret** settings in pnpm's actual global configuration. It deliberately does not put pnpm's config in this public repo: registry access tokens or scoped registry credentials can live alongside these settings. It requires pnpm 12 and is safe to re-run.

pnpm prevents most dependency install/build scripts from executing unless approved. Approve a dependency build only after inspecting why it needs it. The policy enforces 24-hour release age, trust-policy no-downgrade, blocking exotic transitive dependencies, and strict dependency builds. It does **not** sandbox the binaries you later run.

Do not delete the pnpm store, npm cache or existing Node installation as part of this procedure.

### 3. Declare only CLI tools in mise

Existing `npm:difit` remains managed by mise; its installer becomes pnpm through `npm.package_manager`. For additional audited global commands, add entries to `~/.config/mise/config.toml` **in the chezmoi source repository**:

```toml
[tools]
node = "latest"
pnpm = "12"
"npm:example-cli" = "1.2.3"
[settings]
npm.package_manager = "pnpm"
```

The `example-cli` entry above is illustrative; do not install it verbatim. For each actual tool, check its publisher, binaries, dependencies, install scripts, upstream release and availability. Avoid `latest` for newly adopted tools when reproducibility is important. Keep the generated `mise.lock` updated (the repo already tracks it via chezmoi).

```bash
pnpm-policy.sh --check
mise install
mise lock --global
mise reshim
chezmoi diff
```

Commit reviewed config and generated lock changes. Never manually edit the generated lockfile. In this PR, `mise.lock` is intentionally **not** regenerated because it requires your local mise/platform resolution.

### 4. Verify every replacement before uninstalling old npm globals

For each CLI, compare the old npm path and the new mise shim and test the actual command:

```bash
type -a difit
mise which difit
mise exec -- difit --help
```

Some tools have different executable names from package names; use `npm view PACKAGE bin --json` and `type -a EXECUTABLE` to find the right binary. If the expected CLI is not functional, restore/fix it before removing anything. Check automation scripts, IDE/Raycast integrations and LaunchAgents for hard-coded old paths.

### 5. Remove previous npm globals (manual, one prefix at a time)

After each replacement passes verification, remove *only* the old npm global package from the corresponding npm executable/prefix. For example, when that package **really is** installed via the current `npm`:

```bash
npm prefix -g
npm ls -g --depth=0
npm uninstall -g PACKAGE_NAME
hash -r
type -a EXECUTABLE
mise which EXECUTABLE
```

If a package belongs to a different Node version, run that version's **absolute** npm executable for uninstall. Do not `sudo npm uninstall` blindly. Do not automatically remove `npm`, Node, corepack, a whole prefix, or `node_modules`. When nothing depends on an old Node version, remove it through its owner (mise/nvm/Homebrew), not with `rm -rf`. There is **no safe generic bulk-uninstall** command for unknown packages and prefixes.

If you want npm CLI usage to be explicitly rejected rather than merely unmanaged, add a separate shell policy *after* checking package scripts and editor integrations; npm itself still ships with Node and some tooling needs it.

### 6. Validate IaC convergence

```bash
chezmoi diff
chezmoi apply
mise install
pnpm-policy.sh --check
node-global-audit.sh
mise ls --global
git -C "$(chezmoi source-path)" status --short
```

Apply is not intended to remove global tools. New machine bootstrap still requires Homebrew, chezmoi, mise, then `mise install` before pnpm-dependent `npm:` tools are installed. Avoid assuming chezmoi's `run_once` scripts configure Node tools: the current repository only runs Homebrew and Raycast setup from those scripts.

## Compatibility / follow-ups

- The existing OpenCode config uses `op-anthropic-auth@latest`, not ex-machina. Plugin sourcing needs a separate audit before changing to OpenCode v2.
- Raycast memo-search currently uses `bun install --frozen-lockfile`, so it should not be casually converted.
- Topgrade's npm step is disabled to avoid bypassing mise/pnpm ownership; mise's existing upgrade behavior remains unchanged.
- Avoid committing `~/.npmrc`, `pnpm config` exports, token files, and machine inventory.
- For stronger long-term reproducibility, replace `latest` entries with reviewed versions and use the generated mise lockfile.
