# DSH configuration

`chezmoi apply` reproduces the pinned DSH runtime, the shared plugin baseline, and the shared policy.
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
| Bump DSH | Change the version in `dot_local/bin/executable_dsh` and the dependency versions in `modify_private_package.json` together, then check that `dsh web` starts |

## Notion server

- The patch defines the Notion MCP server as disabled, because an unused server adds tool definitions to every request.
- A profile patch that defines the same id as well produces two entries, so remove the profile copy after the first apply.

## Not shared

- Web UI preferences such as language, transcript view, and dismissed notices.
- The scheduled preset, which mounts a plugin from a local repository.
- The `headless` profile and any other profile than `web`.
- Automatic DSH and plugin updates.

## Risks

- The shared policy sets approval `never` with full access, so every restored Mac inherits it.
- The pinned DSH release is a prerelease, so a bump needs the coordinated change above.
- The first restore needs network access for `npx` and `pnpm`. A failed install prints a message and the apply still succeeds, so run `dsh plugin --profile web install` again before `dsh web`.
- The home patch applies to every profile, so a Notion server that someone enables is defined in profiles that did not load it before.
- A UI change to a setting that the home patch overrides is refused, and a change to a managed dependency or bundle is restored by the next apply.
- Local additions are preserved, but their transitive versions can differ between Macs.
