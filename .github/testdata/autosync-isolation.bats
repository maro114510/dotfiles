#!/usr/bin/env bats
#
# Integration tests for dotfiles-autosync.sh. One command runs every case:
#   - a sync from a work branch or a dirty checkout never changes the source
#     checkout, and its temporary worktree of origin/main is removed on success
#     and on failure
#   - a sync stops when origin/main changed a file it would write
#   - two runs started at once never push or open a PR at the same time
#   - a run with nothing to sync exits without a PR
#
# Each test builds a throwaway chezmoi source, destination, and bare origin in
# a sandbox, then runs the script against them with a fake gh and a fake
# notifier. Pushes go to the bare repository inside the sandbox: nothing leaves
# the machine, and no notification reaches the desktop.
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

  # The notifier is stubbed like gh: a real failing run would otherwise pop a
  # macOS banner on the machine running this suite, and a test could not tell
  # what the script asked to show.
  NOTIFY_LOG="${sandbox}/notify.log"
  : > "${NOTIFY_LOG}"
  cat > "${bin_dir}/osascript" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${NOTIFY_LOG}"
exit 0
EOF
  chmod +x "${bin_dir}/osascript"

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
# and directories, a fake gh and notifier, and a TMPDIR the test can inspect
# afterwards. A run is muted, so no failure pops a banner while the suite runs.
# fd 3 is closed because the script's timeout watchers leave a sleep behind, and
# bats would otherwise wait for it, minutes after the last test finished.
run_autosync() {
  env -u XDG_CONFIG_HOME -u XDG_DATA_HOME \
    HOME="${home_dir}" \
    XDG_STATE_HOME="${sandbox}/state" \
    XDG_CACHE_HOME="${sandbox}/cache" \
    TMPDIR="${tmp_dir}" \
    GH_LOG="${GH_LOG}" \
    NOTIFY_LOG="${NOTIFY_LOG}" \
    DOTFILES_AUTOSYNC_NO_NOTIFY=1 \
    PATH="${bin_dir}:${PATH}" \
    bash "${repo_root}/dot_local/bin/executable_dotfiles-autosync.sh" nvim 3>&-
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

  # Advance origin/main without moving the source checkout's own main: the sync
  # has to build on the remote tip, not on the branch the source left behind.
  git clone --quiet "${remote_dir}" "${sandbox}/other"
  git -C "${sandbox}/other" config user.email "autosync-test@example.com"
  git -C "${sandbox}/other" config user.name "autosync test"
  printf 'remote edit\n' >> "${sandbox}/other/README.md"
  git -C "${sandbox}/other" commit --quiet --no-verify --all --message "remote edit"
  git -C "${sandbox}/other" push --quiet origin main

  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -eq 0 ]
  [ "$(git -C "${source_dir}" branch --show-current)" = "feature/x" ]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${source_head_before}" ]
  [ "$(git -C "${source_dir}" status --porcelain)" = "${source_status_before}" ]

  [ "$(git -C "${remote_dir}" rev-parse 'chore/autosync^')" = "$(git -C "${remote_dir}" rev-parse main)" ]
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

# A rejected push is a failure a person would be notified about, so without the
# mute this run would reach the sandbox's osascript stub.
@test "sends no notification when DOTFILES_AUTOSYNC_NO_NOTIFY is set" {
  printf '#!/bin/bash\nexit 1\n' > "${remote_dir}/hooks/pre-receive"
  chmod +x "${remote_dir}/hooks/pre-receive"
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -ne 0 ]
  [ ! -s "${NOTIFY_LOG}" ]
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

# A second clone stands in for "someone else changed origin/main"; the live
# copy here is still the content the local base was applied from, so a sync
# would write it back over the newer remote config.
@test "stops without a PR when origin changed a file in the sync scope" {
  git clone --quiet "${remote_dir}" "${sandbox}/other"
  git -C "${sandbox}/other" config user.email "autosync-test@example.com"
  git -C "${sandbox}/other" config user.name "autosync test"
  printf '{"remote": true}\n' > "${sandbox}/other/dot_config/nvim/lazy-lock.json"
  git -C "${sandbox}/other" commit --quiet --no-verify --all --message "remote change"
  git -C "${sandbox}/other" push --quiet origin main

  printf '{"old": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"
  source_head_before="$(git -C "${source_dir}" rev-parse HEAD)"
  source_status_before="$(git -C "${source_dir}" status --porcelain)"

  run run_autosync

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"dot_config/nvim/lazy-lock.json"* ]]
  [ ! -s "${GH_LOG}" ]
  run git -C "${remote_dir}" rev-parse --verify --quiet refs/heads/chore/autosync
  [ "${status}" -ne 0 ]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${source_head_before}" ]
  [ "$(git -C "${source_dir}" status --porcelain)" = "${source_status_before}" ]
  [ "$(temporary_worktree_count)" -eq 1 ]
  [ -z "$(temporary_worktree_dirs)" ]
}

@test "creates a PR when origin changed only files outside the sync scope" {
  git clone --quiet "${remote_dir}" "${sandbox}/other"
  git -C "${sandbox}/other" config user.email "autosync-test@example.com"
  git -C "${sandbox}/other" config user.name "autosync test"
  printf 'remote edit\n' >> "${sandbox}/other/README.md"
  git -C "${sandbox}/other" commit --quiet --no-verify --all --message "remote edit"
  git -C "${sandbox}/other" push --quiet origin main

  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -eq 0 ]
  [ "$(git -C "${remote_dir}" show "chore/autosync:dot_config/nvim/lazy-lock.json")" = '{"new": true}' ]
  grep -q -- '--head chore/autosync' "${GH_LOG}"
}

# A slow pre-receive hook and a slow fake gh pr create each log when they enter
# and leave the part of a run that publishes. Two runs overlapping there would
# race on the same branch and PR, so no moment may have two runs inside.
@test "never pushes or opens a PR from two runs at the same time" {
  gh_state="${sandbox}/pr-exists"
  phase_log="${sandbox}/phases.log"
  cat > "${bin_dir}/gh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${GH_LOG}"
case "${1:-} ${2:-}" in
  "pr list")
    if [ -e "${GH_STATE}" ]; then printf '1\n'; fi
    exit 0
    ;;
  "pr create")
    printf 'begin pr-create\n' >> "${PHASE_LOG}"
    sleep 1
    if [ -e "${GH_STATE}" ]; then
      printf 'end pr-create\n' >> "${PHASE_LOG}"
      exit 1
    fi
    : > "${GH_STATE}"
    printf 'end pr-create\n' >> "${PHASE_LOG}"
    printf 'https://example.invalid/pull/1\n'
    exit 0
    ;;
  "pr view") printf '1\n'; exit 0 ;;
esac
exit 0
EOF
  cat > "${remote_dir}/hooks/pre-receive" <<EOF
#!/bin/bash
printf 'begin push\n' >> "${phase_log}"
sleep 1
printf 'end push\n' >> "${phase_log}"
EOF
  chmod +x "${remote_dir}/hooks/pre-receive"
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  first_status=0
  second_status=0
  GH_STATE="${gh_state}" PHASE_LOG="${phase_log}" run_autosync >/dev/null 2>&1 &
  first_pid=$!
  GH_STATE="${gh_state}" PHASE_LOG="${phase_log}" run_autosync >/dev/null 2>&1 &
  second_pid=$!
  wait "${first_pid}" || first_status=$?
  wait "${second_pid}" || second_status=$?

  [ "${first_status}" -eq 0 ]
  [ "${second_status}" -eq 0 ]

  # Both runs reached the push, so the overlap check below is not vacuous.
  [ "$(grep -c '^begin push$' "${phase_log}")" -eq 2 ]
  max_inside="$(awk '/^begin /{n++; if (n>m) m=n} /^end /{n--} END{print m+0}' "${phase_log}")"
  [ "${max_inside}" -eq 1 ]

  [ "$(git -C "${remote_dir}" show "chore/autosync:dot_config/nvim/lazy-lock.json")" = '{"new": true}' ]
  [ "$(temporary_worktree_count)" -eq 1 ]
  [ -z "$(temporary_worktree_dirs)" ]
}

# The lock is a symlink named after the holder's pid. A run that dies without
# cleaning up leaves it behind, and a later run has to take it over once it is
# old enough instead of waiting out LOCK_WAIT_SECONDS.
@test "takes over a stale lock left by a dead run" {
  lock="${sandbox}/cache/dotfiles-autosync.lock"
  mkdir -p "${sandbox}/cache"
  ln -s 999999 "${lock}"
  touch -h -t 200001010000 "${lock}"
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -eq 0 ]
  [ ! -e "${lock}" ] && [ ! -L "${lock}" ]
  [ "$(git -C "${remote_dir}" show "chore/autosync:dot_config/nvim/lazy-lock.json")" = '{"new": true}' ]
}

@test "leaves no lock behind after a run" {
  printf '{"new": true}\n' > "${home_dir}/.config/nvim/lazy-lock.json"

  run run_autosync

  [ "${status}" -eq 0 ]
  [ ! -e "${sandbox}/cache/dotfiles-autosync.lock" ] && [ ! -L "${sandbox}/cache/dotfiles-autosync.lock" ]
}
