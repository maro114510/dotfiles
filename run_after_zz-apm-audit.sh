#!/bin/bash
# Reports a failed APM deployment at the end of every apply.
#
# The audit runs from the user-scope directory: run from $HOME it passes even
# when deployed skill files are missing, which is how a broken deployment stayed
# invisible. Exits non-zero so the person who ran the apply sees the failure.
set -uo pipefail

command -v apm >/dev/null 2>&1 || exit 0

cd "${HOME}/.apm" 2>/dev/null || {
  echo "apm audit: ${HOME}/.apm is missing" >&2
  exit 1
}

if ! apm audit --ci; then
  echo "apm audit failed: run 'apm install -g' to restore the deployed skills" >&2
  exit 1
fi
