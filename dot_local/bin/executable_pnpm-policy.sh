#!/usr/bin/env bash
# Converge only non-secret pnpm 12 security settings.
# The real global config may contain registry credentials: do not add it to chezmoi.
set -euo pipefail

usage() { printf 'Usage: %s --check | --apply\n' "${0##*/}" >&2; }
mode="${1:-}"
case "$mode" in --check|--apply) ;; *) usage; exit 2 ;; esac

if ! command -v pnpm >/dev/null 2>&1; then
  printf 'error: pnpm is not available; install it with mise first\n' >&2
  exit 1
fi
version="$(MISE_NOT_FOUND_AUTO_INSTALL=false pnpm --version)" || exit 1
case "$version" in
  12.*) ;;
  *) printf 'error: pnpm 12 required; found %s\n' "$version" >&2; exit 1 ;;
esac

check_one() {
  local key="$1" expected="$2" actual
  actual="$(pnpm config get --json "$key")" || return 1
  if [[ "$actual" != "$expected" ]]; then
    printf '%s: expected %s, got %s\n' "$key" "$expected" "$actual" >&2
    return 1
  fi
}

check_all() {
  local ok=0
  check_one minimumReleaseAge 1440 || ok=1
  check_one blockExoticSubdeps true || ok=1
  check_one strictDepBuilds true || ok=1
  check_one trustPolicy '"no-downgrade"' || ok=1
  return "$ok"
}

if [[ "$mode" == --check ]]; then
  check_all
  printf 'pnpm 12 security policy: OK\n'
  exit 0
fi

# pnpm config set preserves unrelated auth/registry settings. Never write,
# print, or version-control pnpm's global config.yaml directly.
pnpm config set --global --json minimumReleaseAge 1440
pnpm config set --global --json blockExoticSubdeps true
pnpm config set --global --json strictDepBuilds true
pnpm config set --global --json trustPolicy '"no-downgrade"'
check_all
printf 'pnpm 12 security policy applied. Do not commit the global config file.\n'
