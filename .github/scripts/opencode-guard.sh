#!/usr/bin/env bash
# Refuses what a model-written change must not carry into a pull request.
#
# Usage:
#   opencode-guard.sh patch <patch-file>   refuse a patch holding the API key
#   opencode-guard.sh paths                refuse NUL-separated paths on stdin
#
# patch: the repository is public and the model can read the key from its
#   environment, so a patch holding the key format "oc_sk_" or this run's key
#   value is refused.
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
  patch)
    [[ $# -eq 2 ]] || { echo "Usage: opencode-guard.sh patch <patch-file>" >&2; exit 2; }
    file=$2
    if grep -qF 'oc_sk_' "${file}"; then
      echo "opencode-guard: the patch holds the API key format" >&2
      exit 1
    fi
    if [[ -n "${OPENCODE_API_KEY:-}" ]] && grep -qF -- "${OPENCODE_API_KEY}" "${file}"; then
      echo "opencode-guard: the patch holds this run's API key" >&2
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
    echo "Usage: opencode-guard.sh patch <patch-file> | paths" >&2
    exit 2
    ;;
esac
