#!/bin/bash
# Installs the web and headless profiles' plugin dependencies after their manifests are deployed.
# Skips with a message, and still succeeds, when a prerequisite is missing or an install fails,
# so a bare or offline Mac can finish its apply; the next apply retries.
set -uo pipefail
dsh_bin="${HOME}/.local/bin/dsh"
[ -x "${dsh_bin}" ] || { echo "dsh wrapper not found; skipping DSH profile install" >&2; exit 0; }
command -v npx >/dev/null 2>&1 || { echo "npx not found; skipping DSH profile install" >&2; exit 0; }
command -v pnpm >/dev/null 2>&1 || { echo "pnpm not found; skipping DSH profile install" >&2; exit 0; }
for profile in web headless; do
  manifest="${HOME}/.dsh/profiles/${profile}/package.json"
  [ -f "${manifest}" ] || { echo "${profile} profile manifest not found; skipping DSH profile install" >&2; continue; }
  "${dsh_bin}" plugin --profile "${profile}" install || echo "DSH profile install failed; run 'dsh plugin --profile ${profile} install' again" >&2
done
exit 0
