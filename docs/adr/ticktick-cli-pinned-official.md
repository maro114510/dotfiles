# Run the official TickTick CLI at a pinned version, with its token injected from 1Password

## Context
Shell and coding agents need to read and write TickTick tasks without `npm install -g` or `npx`.
The official package's source repository is not public and the package has no provenance.
The CLI reads its token only from a plaintext `~/.config/ticktick-cli/config.json`, with no environment or keychain support.

## Decision
Pin `@ticktick/ticktick-cli` to 0.1.15 in mise, which installs it with pnpm.
Run it only through `ticktick-op.sh`, which for each run:

- Writes the token from 1Password into a throwaway HOME.
- Starts the CLI with a minimal environment.
- Redacts the token from stderr.
- Requires a typed confirmation from a person for every subcommand outside a read, create, update and complete allowlist.

## Rationale
- The official tarball is readable JavaScript with no install scripts, 15 packages in total, no known advisories, and contact only with TickTick hosts.
- It authenticates as a public PKCE client, so no client secret exists to protect.
- The Rust CLI by CarterT27 lost because its lockfile pins crates with TLS advisories, it has no LICENSE file, it has one author, and its default token exchange goes through a third-party broker.
- The Go CLI by avilabss lost because it requires a browser session cookie stored in `.env`.
- Installing nothing lost because the official CLI is acceptable once pinned and wrapped.

## Consequences
- The pinned package cannot be matched to source, so every version change needs a diff of the new tarball.
- During each run the token sits in a mode-0600 file that any process of the same user can read.
- The confirmation guard stops accidents, not an agent that can run `op` itself.
- The API echoes a rejected token in its 401 body; the wrapper redacts stderr only.
- There is no refresh token, so an expired token needs a new login.
- The CLI has no archive or export command, and shows a project's closed flag read-only.
