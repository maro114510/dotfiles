#!/usr/bin/env bats
#
# Verifies that dotfiles-autosync.sh never changes the chezmoi source checkout:
# the sync commit is built in a temporary worktree of origin/main, and that
# worktree is removed on success and on failure.
#
# Each test builds a throwaway chezmoi source, destination, and bare origin in
# a sandbox, then runs the script against them with a fake gh. Pushes go to the
# bare repository inside the sandbox: nothing leaves the machine.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/autosync-isolation.bats
# Set CHEZMOI to the chezmoi binary when it is not on PATH.

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"

  sandbox="$(mktemp -d)"
  home_dir="${sandbox}/home"
  source_dir="${sandbox}/source"
  remote_dir="${sandbox}/origin.git"
  tmp_dir="${sandbox}/tmp"
  bin_dir="${sandbox}/bin"
  mkdir -p \
    "${home_dir}/.config/chezmoi" \
    "${home_dir}/.config/nvim" \
    "${source_dir}/dot_config/nvim" \
    "${tmp_dir}" \
    "${bin_dir}"

  GH_LOG="${sandbox}/gh.log"
  cat > "${bin_dir}/gh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${GH_LOG}"
case "${1:-} ${2:-}" in
  "pr list") exit 0 ;;
  "pr create") printf 'https://example.invalid/pull/1\n'; exit 0 ;;
  "pr view") printf '1\n'; exit 0 ;;
esac
exit 0
EOF
  chmod +x "${bin_dir}/gh"

  cat > "${home_dir}/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "${source_dir}"
destDir = "${home_dir}"

[git]
  autoCommit = false
  autoPush   = false
EOF

  printf '{"old": true}\n' > "${source_dir}/dot_config/nvim/lazy-lock.json"
  printf 'initial\n' > "${source_dir}/README.md"
  git init --quiet --initial-branch=main "${source_dir}"
  git -C "${source_dir}" config user.email "autosync-test@example.com"
  git -C "${source_dir}" config user.name "autosync test"
  git -C "${source_dir}" add -A
  git -C "${source_dir}" commit --quiet --no-verify --message "initial"

  git init --quiet --bare --initial-branch=main "${remote_dir}"
  git -C "${source_dir}" remote add origin "${remote_dir}"
  git -C "${source_dir}" push --quiet origin main

  env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="${home_dir}" \
    "${chezmoi_bin}" apply
}

teardown() {
  rm -rf "${sandbox}"
}

# Runs the script the way a shell on this machine does: only the sandbox home
# and directories, a fake gh, and a TMPDIR the test can inspect afterwards.
run_autosync() {
  env -u XDG_CONFIG_HOME -u XDG_DATA_HOME \
    HOME="${home_dir}" \
    XDG_STATE_HOME="${sandbox}/state" \
    XDG_CACHE_HOME="${sandbox}/cache" \
    TMPDIR="${tmp_dir}" \
    GH_LOG="${GH_LOG}" \
    PATH="${bin_dir}:${PATH}" \
    bash "${repo_root}/dot_local/bin/executable_dotfiles-autosync.sh" nvim
}

temporary_worktree_count() {
  git -C "${source_dir}" worktree list --porcelain | grep -c '^worktree '
}

temporary_worktree_dirs() {
  find "${tmp_dir}" -maxdepth 1 -name 'dotfiles-autosync.*' -print
}

@test "syncs from a dirty work branch and leaves the source untouched" {
  git -C "${source_dir}" switch --quiet -c feature/x
  printf 'local edit\n' >> "${source_dir}/README.md"
  printf 'untracked\n' > "${source_dir}/NOTES.md"
  source_head_before="$(git -C "${source_dir}" rev-parse HEAD)"
  source_status_before="$(git -C "${source_dir}" status --porcelain)"
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -eq 0 ]
  [ "$(git -C "${source_dir}" branch --show-current)" = "feature/x" ]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${source_head_before}" ]
  [ "$(git -C "${source_dir}" status --porcelain)" = "${source_status_before}" ]

  [ "$(git -C "${remote_dir}" show "chore/autosync:dot_config/nvim/lazy-lock.json")" = '{"new": true}' ]
  grep -q -- '--head chore/autosync' "${GH_LOG}"

  [ "$(temporary_worktree_count)" -eq 1 ]
  [ -z "$(temporary_worktree_dirs)" ]
}

@test "removes the temporary worktree when the push fails" {
  printf '#!/bin/bash\nexit 1\n' > "${remote_dir}/hooks/pre-receive"
  chmod +x "${remote_dir}/hooks/pre-receive"
  git -C "${source_dir}" switch --quiet -c feature/x
  printf 'local edit\n' >> "${source_dir}/README.md"
  source_head_before="$(git -C "${source_dir}" rev-parse HEAD)"
  source_status_before="$(git -C "${source_dir}" status --porcelain)"
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -ne 0 ]
  [ "$(git -C "${source_dir}" branch --show-current)" = "feature/x" ]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${source_head_before}" ]
  [ "$(git -C "${source_dir}" status --porcelain)" = "${source_status_before}" ]
  [ "$(temporary_worktree_count)" -eq 1 ]
  [ -z "$(temporary_worktree_dirs)" ]
}

@test "exits without a PR when nothing changed" {
  run run_autosync

  [ "${status}" -eq 0 ]
  [ ! -s "${GH_LOG}" ]
  run git -C "${remote_dir}" rev-parse --verify --quiet refs/heads/chore/autosync
  [ "${status}" -ne 0 ]
  [ "$(temporary_worktree_count)" -eq 1 ]
  [ -z "$(temporary_worktree_dirs)" ]
}
