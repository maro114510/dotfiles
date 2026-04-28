#!/bin/bash
# Invoked automatically by `chezmoi apply` via the run_once_after_ filename prefix.
# Runs once per unique script content; re-runs only when this file is modified.

set -euo pipefail

BREWFILE="${HOME}/.Brewfile"

if ! command -v brew &>/dev/null; then
  echo "Homebrew not found — skipping brew bundle." >&2
  exit 0
fi

if [ ! -f "${BREWFILE}" ]; then
  echo "No Brewfile found at $BREWFILE — skipping." >&2
  exit 0
fi

echo "Running brew bundle..."
brew bundle --file="${BREWFILE}"
echo "brew bundle complete."
