#!/bin/bash
# Verifies that `chezmoi apply` installs packages when the Brewfile changes and
# only then.
#
# The test runs a real `chezmoi apply` against a throwaway source and destination
# in a temporary directory, with a fake `brew` that records each invocation. The
# real $HOME and the real brew are never touched.
#
# Only the brew-bundle script is copied into the sandbox source so that no other
# run_ script, such as the macOS defaults one, executes here.
#
# Usage: bash .github/testdata/brew-bundle-run-onchange.sh
# Set CHEZMOI to the chezmoi binary when it is not on PATH.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
chezmoi_bin=${CHEZMOI:-chezmoi}

sandbox=$(mktemp -d)
trap 'rm -rf "${sandbox}"' EXIT

source_dir="${sandbox}/source"
destination_dir="${sandbox}/home"
bin_dir="${sandbox}/bin"
brew_log="${sandbox}/brew.log"

mkdir -p "${source_dir}" "${destination_dir}" "${bin_dir}"

cp "${repo_root}/dot_Brewfile" "${source_dir}/dot_Brewfile"

brew_scripts=("${repo_root}"/run_*brew-bundle*)
if [ ! -e "${brew_scripts[0]}" ]; then
  echo "FAIL: no run_*brew-bundle* script found in ${repo_root}" >&2
  exit 1
fi
cp "${brew_scripts[@]}" "${source_dir}/"

cat > "${bin_dir}/brew" <<'EOF'
#!/bin/sh
echo "brew $*" >> "${BREW_LOG}"
EOF
chmod +x "${bin_dir}/brew"

failures=0

brew_bundle_runs() {
  local count
  count=$(grep -c 'brew bundle' "${brew_log}" 2>/dev/null || true)
  echo "${count:-0}"
}

assert_brew_bundle_runs() {
  local description=$1 expected=$2 actual
  actual=$(brew_bundle_runs)
  if [ "${actual}" -ne "${expected}" ]; then
    echo "FAIL: ${description}: expected ${expected} brew bundle run(s), got ${actual}" >&2
    failures=$((failures + 1))
  else
    echo "ok: ${description}"
  fi
}

apply() {
  HOME="${destination_dir}" BREW_LOG="${brew_log}" PATH="${bin_dir}:${PATH}" \
    "${chezmoi_bin}" apply --source "${source_dir}" --destination "${destination_dir}"
}

apply
assert_brew_bundle_runs "first chezmoi apply on an unapplied sandbox runs brew bundle" 1

apply
assert_brew_bundle_runs "chezmoi apply without a Brewfile change does not run brew bundle" 1

printf 'brew "fzf"\n' >> "${source_dir}/dot_Brewfile"
apply
assert_brew_bundle_runs "chezmoi apply after a Brewfile change runs brew bundle" 2

apply
assert_brew_bundle_runs "chezmoi apply without a further Brewfile change does not run brew bundle" 2

if [ "${failures}" -ne 0 ]; then
  echo "${failures} assertion(s) failed" >&2
  exit 1
fi
