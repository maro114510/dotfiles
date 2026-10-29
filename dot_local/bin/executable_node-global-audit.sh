#!/usr/bin/env bash
# Read-only inventory of npm global installs across common macOS Node managers.
# Never reads npm auth configuration or installs/uninstalls packages.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf 'error: jq is required (brew install jq)\n' >&2
  exit 1
fi

shopt -s nullglob
npm_bins=()

add_npm() {
  local candidate="$1" existing
  [[ -x "$candidate" ]] || return 0
  for existing in "${npm_bins[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  npm_bins+=("$candidate")
}

while IFS= read -r candidate; do
  [[ -n "$candidate" ]] && add_npm "$candidate"
done < <(type -ap npm 2>/dev/null || true)

for candidate in \
  /opt/homebrew/bin/npm \
  /usr/local/bin/npm \
  "$HOME"/.local/share/mise/installs/node/*/bin/npm \
  "$HOME"/.nvm/versions/node/*/bin/npm \
  "$HOME"/.asdf/installs/nodejs/*/bin/npm \
  "$HOME"/.nodenv/versions/*/bin/npm \
  "$HOME"/.volta/tools/image/node/*/bin/npm; do
  add_npm "$candidate"
done

printf '# Global npm inventory (read only)\n'
printf '# Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '# Does not prove that every Node version or package manager was discovered.\n'
printf '# Never commit machine inventory or authentication files to dotfiles.\n'

if (( ${#npm_bins[@]} == 0 )); then
  printf 'No npm executable found in PATH or common Node manager locations.\n'
  exit 0
fi

# Duplicate npm shims can lead to the same prefix. Keep the paths visible,
# but only print the global package list once per distinct prefix.
seen_prefixes=()
for npm_bin in "${npm_bins[@]}"; do
  printf '\n## npm executable: %s\n' "$npm_bin"
  prefix="$(MISE_NOT_FOUND_AUTO_INSTALL=false "$npm_bin" prefix -g 2>/dev/null || true)"
  if [[ -z "$prefix" ]]; then
    printf 'Could not determine npm prefix; skipped.\n'
    continue
  fi
  printf 'npm prefix: %s\n' "$prefix"
  duplicate=0
  for existing in "${seen_prefixes[@]}"; do
    if [[ "$existing" == "$prefix" ]]; then duplicate=1; break; fi
  done
  if (( duplicate )); then
    printf 'Prefix already inventoried; skipped duplicate.\n'
    continue
  fi
  seen_prefixes+=("$prefix")

  output="$(MISE_NOT_FOUND_AUTO_INSTALL=false "$npm_bin" ls -g --depth=0 --json 2>/dev/null || true)"
  if [[ -z "$output" ]] || ! printf '%s\n' "$output" | jq -e 'type == "object"' >/dev/null 2>&1; then
    printf 'Could not parse npm global package list; inspect manually.\n'
    continue
  fi
  printf '%s\n' "$output" | jq -r '
    (.dependencies // {} | to_entries | sort_by(.key)[])
    | "  " + .key + "@" + (.value.version // "unknown")
  '
  printf '# Candidate mise entries (review; not all global packages are CLIs):\n'
  printf '%s\n' "$output" | jq -r '
    (.dependencies // {} | to_entries | sort_by(.key)[])
    | select(.key != "npm" and .key != "corepack" and .key != "pnpm")
    | select(.value.version != null)
    | "  \"npm:" + .key + "\" = \"" + .value.version + "\""
  '
done

printf '\n# Existing package-manager and tool declarations (informational):\n'
if command -v mise >/dev/null 2>&1; then
  MISE_NOT_FOUND_AUTO_INSTALL=false mise ls --global 2>/dev/null || true
fi
if command -v pnpm >/dev/null 2>&1; then
  MISE_NOT_FOUND_AUTO_INSTALL=false pnpm ls --global --depth=0 2>/dev/null || true
fi
