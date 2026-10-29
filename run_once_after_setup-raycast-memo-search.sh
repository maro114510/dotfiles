#!/bin/bash
# chezmoi run_once_after_ script: set up Raycast memo-search extension
#
# Bun is a mise-managed tool, so on a fresh Mac this script runs before
# `mise install` has provided it. It must therefore stop without recording a
# successful run: chezmoi keeps a run_once script pending while it exits
# non-zero, so the next `chezmoi apply` retries it once Bun is available.

set -euo pipefail

EXTENSION_DIR="${HOME}/.raycast/memo-search"

# Check Bun before entering the extension directory: when Bun is missing the
# deployed directory may be missing too, and a cd error would hide the cause.
if ! command -v bun &>/dev/null; then
  echo "Error: Bun is required to set up the Raycast memo-search extension, but it is not on PATH." >&2
  echo "Install the mise-managed tool and re-run 'chezmoi apply':" >&2
  echo "  mise install bun" >&2
  exit 1
fi

echo "Setting up Raycast memo-search extension in ${EXTENSION_DIR}..."

cd "${EXTENSION_DIR}"

# Install exactly the versions bun.lock records; fail instead of rewriting it.
bun install --frozen-lockfile

# Build the extension
bun run build

echo "Raycast memo-search extension setup complete."
echo "To register the extension in Raycast: Raycast -> Import Extension -> ${EXTENSION_DIR}"
