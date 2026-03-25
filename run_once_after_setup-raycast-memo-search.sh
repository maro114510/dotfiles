#!/bin/bash
# chezmoi run_once_after_ script: set up Raycast memo-search extension

set -euo pipefail

EXTENSION_DIR="${HOME}/.raycast/memo-search"

echo "Setting up Raycast memo-search extension in ${EXTENSION_DIR}..."

cd "${EXTENSION_DIR}"

# Check if Bun is installed
if ! command -v bun &>/dev/null; then
  echo "Error: bun is not installed. Please install it first: brew install bun" >&2
  exit 1
fi

# Install dependencies
bun install --frozen-lockfile

# Build the extension
bun run build

echo "Raycast memo-search extension setup complete."
echo "To register the extension in Raycast: Raycast -> Import Extension -> ${EXTENSION_DIR}"
