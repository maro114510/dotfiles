#!/usr/bin/env bash
# Refuses what a model-written change must not carry into a pull request.
#
# Usage:
#   opencode-guard.sh staged               refuse staged changes holding the API key
#   opencode-guard.sh paths                refuse NUL-separated paths on stdin
#
# staged: the repository is public and the model can read the key from its
#   environment, so staged changes holding the key format "oc_sk_" or this run's
#   key value are refused. The staged content is searched as text, never the
#   patch that carries it, because git stores a binary file, or any file that
#   .gitattributes marks binary, as compressed base85.
# paths: a workflow, and a file that runs when the checkout is opened or a tool
#   starts, never come from the model. Names are compared case-insensitively,
#   at any depth, because macOS resolves .GitHub to .github.
#
# Exits 1 and names what it refused.
set -euo pipefail

refused_names=(
  .git .github .opencode .envrc .mise
  mise.toml .mise.toml mise.local.toml .mise.local.toml
)

case "${1:-}" in
  staged)
    [[ $# -eq 1 ]] || { echo "Usage: opencode-guard.sh staged" >&2; exit 2; }
    diff="$(mktemp)"
    trap 'rm -f "${diff}"' EXIT
    git diff --cached --text --no-color --no-ext-diff --no-textconv HEAD >"${diff}"
    if grep -aqF 'oc_sk_' "${diff}"; then
      echo "opencode-guard: the staged changes hold the API key format" >&2
      exit 1
    fi
    if [[ -n "${OPENCODE_API_KEY:-}" ]] && grep -aqF -- "${OPENCODE_API_KEY}" "${diff}"; then
      echo "opencode-guard: the staged changes hold this run's API key" >&2
      exit 1
    fi
  ;;
  paths)
    [[ $# -eq 1 ]] || { echo "Usage: opencode-guard.sh paths" >&2; exit 2; }
    status=0
    while IFS= read -r -d '' path; do
      lower="$(printf '%s' "${path}" | tr '[:upper:]' '[:lower:]')"
      IFS=/ read -r -d '' -a segments < <(printf '%s\0' "${lower}") || true
      for segment in "${segments[@]}"; do
        for name in "${refused_names[@]}"; do
          if [[ "${segment}" == "${name}" ]]; then
            printf 'opencode-guard: refused path: %s\n' "${path}" >&2
            status=1
            break 2
          fi
        done
      done
    done
    exit "${status}"
    ;;
  *)
    echo "Usage: opencode-guard.sh staged | paths" >&2
    exit 2
    ;;
esac
