#!/usr/bin/env bats
#
# Integration tests for cleanup-automation.sh. One command runs every case:
#   - daily runs the light prune steps and nothing destructive
#   - a step is skipped, not forced, when a conflicting process is running
#   - one failing step does not stop the others, and the exit code reports it
#   - weekly keeps the npx cache key a running process uses
#   - weekly never runs docker volume prune, docker system prune -a or colima delete
#   - a stopped Colima is started for the run and stopped again afterwards
#   - a merged worktree that a process uses is kept, the others are removed
#   - a run without the process list refuses to remove any worktree
#   - --dry-run changes nothing
#
# Every external tool is a fake in a sandbox bin directory that records its
# arguments, so nothing on the machine is touched.
#
# Usage: bats .github/testdata/cleanup-automation.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  script="${repo_root}/dot_local/bin/executable_cleanup-automation.sh"

  sandbox="$(mktemp -d)"
  export HOME="${sandbox}/home"
  export TMPDIR="${sandbox}/tmp"
  export XDG_STATE_HOME="${sandbox}/state"
  export XDG_CACHE_HOME="${sandbox}/cache"
  export GHQ_ROOT="${sandbox}/ghq"
  export COLIMA_DISK="${sandbox}/datadisk"
  export CLEANUP_LOCK_WAIT_SECONDS=2
  export CLEANUP_LOCK_POLL_SECONDS=1
  bin_dir="${sandbox}/bin"
  mkdir -p "${HOME}" "${TMPDIR}" "${bin_dir}" "${GHQ_ROOT}"
  printf 'x' >"${COLIMA_DISK}"

  CALLS="${sandbox}/calls.log"
  BUSY_FILE="${sandbox}/busy"
  PS_FILE="${sandbox}/ps"
  CWD_LIST="${sandbox}/cwds"
  COLIMA_STATE="${sandbox}/colima-running"
  FAIL_FILE="${sandbox}/fail"
  GTR_CANDIDATES="${sandbox}/gtr-candidates"
  export CALLS BUSY_FILE PS_FILE CWD_LIST COLIMA_STATE FAIL_FILE GTR_CANDIDATES
  : >"${CALLS}"
  : >"${BUSY_FILE}"
  : >"${PS_FILE}"
  printf '/\n' >"${CWD_LIST}"
  : >"${FAIL_FILE}"
  : >"${GTR_CANDIDATES}"
  touch "${COLIMA_STATE}"

  # Every fake records "name args" and fails when its name is in FAIL_FILE.
  for name in mise uv pnpm bun brew go npm docker dotfiles-autosync.sh; do
    cat >"${bin_dir}/${name}" <<EOF
#!/bin/bash
printf '%s %s\n' "${name}" "\$*" >>"\${CALLS}"
if grep -qx "${name}" "\${FAIL_FILE}"; then
  echo "${name}: boom" >&2
  exit 1
fi
EOF
    chmod +x "${bin_dir}/${name}"
  done

  # mise exec -- <cmd> runs <cmd>; mise upgrade --dry-run prints a plan.
  cat >"${bin_dir}/mise" <<'EOF'
#!/bin/bash
printf 'mise %s\n' "$*" >>"${CALLS}"
if grep -qx mise "${FAIL_FILE}"; then
  echo "mise: boom" >&2
  exit 1
fi
if [ "${1:-}" = exec ]; then
  shift 2
  exec "$@"
fi
if [ "${1:-} ${2:-}" = "upgrade --global" ] && [ "${3:-}" = "--dry-run" ] && [ -f "${sandbox_plan:-/nonexistent}" ]; then
  cat "${sandbox_plan}"
fi
exit 0
EOF
  chmod +x "${bin_dir}/mise"
  export sandbox_plan="${sandbox}/plan"

  # npm cache npx ls prints the keys from NPX_KEYS.
  cat >"${bin_dir}/npm" <<'EOF'
#!/bin/bash
printf 'npm %s\n' "$*" >>"${CALLS}"
if [ "${1:-} ${2:-} ${3:-}" = "cache npx ls" ]; then
  cat "${NPX_KEYS}"
fi
exit 0
EOF
  chmod +x "${bin_dir}/npm"
  export NPX_KEYS="${sandbox}/npx-keys"
  : >"${NPX_KEYS}"

  cat >"${bin_dir}/pgrep" <<'EOF'
#!/bin/bash
pattern="${@: -1}"
while IFS= read -r re; do
  [ -n "${re}" ] || continue
  if [ "${re}" = "${pattern}" ] || printf '%s' "${pattern}" | grep -qF -- "${re}"; then
    exit 0
  fi
done <"${BUSY_FILE}"
exit 1
EOF
  chmod +x "${bin_dir}/pgrep"

  cat >"${bin_dir}/ps" <<'EOF'
#!/bin/bash
cat "${PS_FILE}"
EOF
  chmod +x "${bin_dir}/ps"

  cat >"${bin_dir}/lsof" <<'EOF'
#!/bin/bash
if [ "${LSOF_BROKEN:-0}" = 1 ]; then
  exit 1
fi
while IFS= read -r p; do
  printf 'n%s\n' "${p}"
done <"${CWD_LIST}"
EOF
  chmod +x "${bin_dir}/lsof"

  cat >"${bin_dir}/colima" <<'EOF'
#!/bin/bash
printf 'colima %s\n' "$*" >>"${CALLS}"
case "${1:-}" in
  status)
    [ -f "${COLIMA_STATE}" ] && exit 0
    exit 1
    ;;
  start) touch "${COLIMA_STATE}" ;;
  stop) rm -f "${COLIMA_STATE}" ;;
esac
exit 0
EOF
  chmod +x "${bin_dir}/colima"

  cat >"${bin_dir}/docker" <<'EOF'
#!/bin/bash
printf 'docker %s\n' "$*" >>"${CALLS}"
case "${1:-} ${2:-}" in
  "ps -q") ;;
  "system prune")
    if grep -qx docker "${FAIL_FILE}"; then
      echo "docker: boom" >&2
      exit 1
    fi
    echo "Total reclaimed space: 1.5GB" ;;
esac
exit 0
EOF
  chmod +x "${bin_dir}/docker"

  # git-gtr: clean --merged --dry-run lists GTR_CANDIDATES lines; rm records.
  cat >"${bin_dir}/git-gtr" <<'EOF'
#!/bin/bash
printf 'gtr %s (cwd %s, dir %s)\n' "$*" "${PWD}" "${GTR_WORKTREES_DIR:-}" >>"${CALLS}"
case "${1:-}" in
  clean)
    while IFS= read -r line; do
      [ -n "${line}" ] && printf '[OK] [dry-run] Would remove: %s\n' "${line}"
    done <"${GTR_CANDIDATES}"
    echo "[OK] Dry run complete. Would remove: 0, Skipped: 0"
    ;;
esac
exit 0
EOF
  chmod +x "${bin_dir}/git-gtr"

  export PATH="${bin_dir}:${PATH}"
}

teardown() {
  rm -rf "${sandbox}"
}

calls() {
  cat "${CALLS}"
}

# A bare "! cmd" never fails a Bats test, so negative checks go through here.
# Takes the grep options and pattern; fails when any recorded call matches.
not_called() {
  if grep -q "$@" "${CALLS}"; then
    echo "unexpected call matching: ${*}" >&2
    cat "${CALLS}" >&2
    return 1
  fi
}

make_multi_worktree_repo() {
  local name="${1}"
  local dir="${GHQ_ROOT}/github.com/owner/${name}"
  mkdir -p "${dir}"
  git init --quiet --initial-branch=main "${dir}"
  git -C "${dir}" config user.email "t@example.com"
  git -C "${dir}" config user.name "t"
  git -C "${dir}" commit --quiet --allow-empty -m init
  git -C "${dir}" worktree add --quiet -b feat/done "${sandbox}/wt-${name}-done"
  git -C "${dir}" worktree add --quiet -b feat/busy "${sandbox}/wt-${name}-busy"
  printf '%s' "${dir}"
}

@test "daily runs the five light prune steps and nothing destructive" {
  run bash "${script}" daily
  [ "${status}" -eq 0 ]
  calls | grep -qx 'mise cache prune'
  calls | grep -qx 'uv cache prune'
  calls | grep -q 'pnpm store prune'
  calls | grep -q 'bun pm cache prune'
  calls | grep -qx 'brew cleanup'
  not_called 'cache clear'
  not_called 'cache clean'
  not_called 'go clean'
  not_called 'docker'
  not_called 'colima'
  not_called 'gtr'
}

@test "daily writes a Markdown report and a log" {
  run bash "${script}" daily
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"| Step | Result | Detail |"* ]]
  [[ "${output}" == *"| brew cleanup | ok |"* ]]
  [ -s "${XDG_STATE_HOME}/cleanup-automation/cleanup-automation.log" ]
}

@test "a step is skipped when a conflicting process is running" {
  printf '%s\n' 'brew[^ ]* +([^ ]+ +)*(install|upgrade' >"${BUSY_FILE}"
  run bash "${script}" daily
  [ "${status}" -eq 0 ]
  not_called -x 'brew cleanup'
  [[ "${output}" == *"| brew cleanup | skipped | a conflicting process is running |"* ]]
  calls | grep -qx 'uv cache prune'
}

@test "one failing step does not stop the others and the run exits non-zero" {
  printf 'uv\n' >"${FAIL_FILE}"
  run bash "${script}" daily
  [ "${status}" -ne 0 ]
  [[ "${output}" == FAILED:* ]]
  [[ "${output}" == *"| uv cache prune | failed |"* ]]
  calls | grep -qx 'brew cleanup'
}

@test "dry-run changes nothing" {
  run bash "${script}" --dry-run weekly
  [ "${status}" -eq 0 ]
  not_called -E 'cache prune|cache clear|cache clean|go clean|npx rm|system prune|fstrim|gtr rm|colima start|colima stop|upgrade --global$'
}

@test "weekly clears the heavy caches" {
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -qx 'mise cache clear'
  calls | grep -qx 'uv cache clean'
  calls | grep -q 'go clean -cache -modcache'
  calls | grep -qx 'brew cleanup'
}

@test "weekly upgrades only when the dry-run shows a plan, then verifies and syncs" {
  printf 'Would install go@9.9.9\nWould install node@9.9.9\n' >"${sandbox_plan}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -qx 'mise upgrade --global'
  calls | grep -qx 'mise doctor'
  calls | grep -q 'go --version'
  calls | grep -qx 'dotfiles-autosync.sh mise'
  [[ "${output}" == *"upgraded: go@9.9.9,node@9.9.9"* ]]
}

@test "weekly does not upgrade, or sync, when nothing is outdated" {
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  not_called -x 'mise upgrade --global'
  not_called 'dotfiles-autosync.sh'
  [[ "${output}" == *"already up to date"* ]]
}

@test "weekly reports a failed post-upgrade verification and does not sync" {
  printf 'Would install go@9.9.9\n' >"${sandbox_plan}"
  printf 'go\n' >"${FAIL_FILE}"
  run bash "${script}" weekly
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"--version failed for: go"* ]]
  not_called 'dotfiles-autosync.sh'
}

@test "weekly keeps the npx key a running process uses" {
  printf '%s: pkg-a\n%s: pkg-b\n%s: @deepseek-ai/dsh\n' \
    aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb cccccccccccccccc >"${NPX_KEYS}"
  printf 'node /home/u/.npm/_npx/cccccccccccccccc/node_modules/.bin/dsh web\n' >"${PS_FILE}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -qx 'npm cache npx rm aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb'
  not_called 'cccccccccccccccc'
}

@test "weekly removes no npx key when all of them are in use" {
  printf '%s: pkg-a\n' aaaaaaaaaaaaaaaa >"${NPX_KEYS}"
  printf 'node /x/_npx/aaaaaaaaaaaaaaaa/bin/y\n' >"${PS_FILE}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  not_called 'npx rm'
}

@test "weekly prunes docker without -a, without volumes, and never deletes colima" {
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -qx 'docker system prune -f'
  calls | grep -q 'colima ssh -- sudo fstrim -a'
  not_called 'prune -a'
  not_called 'volume prune'
  not_called -- '--volumes'
  not_called 'colima delete'
}

@test "weekly leaves colima running when it was already running" {
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  not_called 'colima start'
  not_called 'colima stop'
}

@test "weekly starts a stopped colima and stops it again" {
  rm -f "${COLIMA_STATE}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -qx 'colima start'
  calls | grep -qx 'colima stop'
  [ ! -f "${COLIMA_STATE}" ]
}

@test "weekly stops a stopped colima even when docker prune fails" {
  rm -f "${COLIMA_STATE}"
  printf 'docker\n' >"${FAIL_FILE}"
  run bash "${script}" weekly
  [ "${status}" -ne 0 ]
  calls | grep -qx 'colima stop'
  [ ! -f "${COLIMA_STATE}" ]
}

@test "weekly skips docker while a docker build is running" {
  printf '%s\n' 'docker[^ ]* +([^ ]+ +)*(build' >"${BUSY_FILE}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  not_called 'system prune'
  not_called 'colima start'
  [[ "${output}" == *"a docker build is running"* ]]
}

@test "merged worktrees: one a process uses is kept, the other is removed" {
  repo="$(make_multi_worktree_repo r1)"
  printf 'feat/done (%s)\nfeat/busy (%s)\n' \
    "${sandbox}/wt-r1-done" "${sandbox}/wt-r1-busy" >"${GTR_CANDIDATES}"
  printf '%s/src\n' "${sandbox}/wt-r1-busy" >"${CWD_LIST}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -q 'gtr rm feat/done --force --yes --delete-branch'
  not_called 'gtr rm feat/busy'
  [[ "${output}" == *"removed 1, in use 1, failed 0"* ]]
  : "${repo}"
}

@test "merged worktrees: the removal log keeps the sha that restores the branch" {
  repo="$(make_multi_worktree_repo r2)"
  printf 'feat/done (%s)\n' "${sandbox}/wt-r2-done" >"${GTR_CANDIDATES}"
  printf '/somewhere/else\n' >"${CWD_LIST}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  sha="$(git -C "${repo}" rev-parse feat/done)"
  grep -q "remove feat/done .* sha=${sha}" "${XDG_STATE_HOME}/cleanup-automation/cleanup-automation.log"
}

@test "merged worktrees: gtr is pointed at an empty directory, not a repo path" {
  make_multi_worktree_repo r3 >/dev/null
  printf 'feat/done (%s)\n' "${sandbox}/wt-r3-done" >"${GTR_CANDIDATES}"
  printf '/somewhere/else\n' >"${CWD_LIST}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  calls | grep -q 'gtr clean --merged --dry-run (cwd .*r3, dir .*/gtr)'
}

@test "merged worktrees: no process list means no worktree is removed" {
  make_multi_worktree_repo r4 >/dev/null
  printf 'feat/done (%s)\n' "${sandbox}/wt-r4-done" >"${GTR_CANDIDATES}"
  LSOF_BROKEN=1 run bash "${script}" weekly
  [ "${status}" -ne 0 ]
  not_called 'gtr rm'
  [[ "${output}" == *"refusing to remove worktrees without the in-use guard"* ]]
}

@test "merged worktrees: a repository with a single worktree is not touched" {
  dir="${GHQ_ROOT}/github.com/owner/solo"
  mkdir -p "${dir}"
  git init --quiet --initial-branch=main "${dir}"
  printf '/x\n' >"${CWD_LIST}"
  run bash "${script}" weekly
  [ "${status}" -eq 0 ]
  not_called 'gtr'
}

@test "a second run waits for the lock and then gives up" {
  mkdir -p "${XDG_CACHE_HOME}"
  sleep 30 &
  holder=$!
  ln -s "${holder}" "${XDG_CACHE_HOME}/cleanup-automation.lock"
  run bash "${script}" daily
  kill "${holder}" 2>/dev/null || true
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"holds the lock"* ]]
  [ ! -s "${CALLS}" ]
}

@test "a lock whose owner is gone is taken over" {
  mkdir -p "${XDG_CACHE_HOME}"
  ln -s 999999 "${XDG_CACHE_HOME}/cleanup-automation.lock"
  run bash "${script}" daily
  [ "${status}" -eq 0 ]
  calls | grep -qx 'brew cleanup'
  [ ! -e "${XDG_CACHE_HOME}/cleanup-automation.lock" ]
}

@test "an unknown profile or a missing one is rejected" {
  run bash "${script}" monthly
  [ "${status}" -eq 2 ]
  run bash "${script}"
  [ "${status}" -eq 2 ]
}
