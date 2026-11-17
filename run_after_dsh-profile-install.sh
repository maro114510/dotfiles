#!/bin/bash
# Installs the web profile's plugin dependencies after the manifest is deployed.
# Skips with a message, and still succeeds, when a prerequisite is missing, so a bare Mac can finish its first apply.
set -euo pipefail
dsh_bin="${HOME}/.local/bin/dsh"
manifest="${HOME}/.dsh/profiles/web/package.json"
[ -x "${dsh_bin}" ] || { echo "dsh wrapper not found; skipping DSH profile install" >&2; exit 0; }
command -v pnpm >/dev/null 2>&1 || { echo "pnpm not found; skipping DSH profile install" >&2; exit 0; }
[ -f "${manifest}" ] || { echo "web profile manifest not found; skipping DSH profile install" >&2; exit 0; }
"${dsh_bin}" plugin --profile web install
