#!/bin/bash
# cleanup-automation.sh: one profile, daily | weekly
# Daily:  prune the package manager caches that only drop stale entries
# Weekly: upgrade the global mise tools, clear the heavy caches, prune Docker
#         and trim the Colima disk, then remove worktrees whose PR is merged
# Guard:  a step that would pull files out from under a running install or
#         build is skipped and reported, never forced
# Report: a Markdown summary on stdout and a log in ~/.local/state
# Never:  docker volume prune, colima delete, docker system prune -a

set -o pipefail

PROG="cleanup-automation"
PROFILE=""
DRY_RUN=0

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/${PROG}"
LOG_FILE="${STATE_DIR}/${PROG}.log"
LOCK_PATH="${XDG_CACHE_HOME:-${HOME}/.cache}/${PROG}.lock"
LOCK_WAIT_SECONDS="${CLEANUP_LOCK_WAIT_SECONDS:-1800}"
LOCK_POLL_SECONDS="${CLEANUP_LOCK_POLL_SECONDS:-5}"
GHQ_ROOT="${GHQ_ROOT:-${HOME}/ghq}"
COLIMA_DISK="${COLIMA_DISK:-${HOME}/.colima/_lima/_disks/colima/datadisk}"
TIMEOUT_SHORT=600
TIMEOUT_LONG=1800
TIMEOUT_WORKTREE=3600

# Tools that must still answer --version after mise upgrade.
VERIFY_TOOLS="go node pnpm bun gh python"

# A process line matching one of these means the step's files are in use.
RE_MISE='(^|/)mise( +-[^ ]+)* +(install|i|upgrade|up|use|prune|uninstall|lock)( |$)'
RE_PNPM='(^|[ /])pnpm(\.c?js)?( +-[^ ]+)* +(install|i|add|update|up|fetch|dlx|rebuild)( |$)'
RE_BUN='(^|[ /])bun( +-[^ ]+)* +(install|i|add|update|pm)( |$)'
RE_BREW='brew[^ ]* +([^ ]+ +)*(install|upgrade|reinstall|bundle|update|uninstall|fetch)( |$)'
RE_GO='(^|/)go( +-[^ ]+)* +(build|test|run|install|vet|generate|get|mod|work)( |$)|/pkg/tool/[^ ]+/(compile|link|cgo|asm)( |$)'
RE_DOCKER='docker[^ ]* +([^ ]+ +)*(build|buildx|--build)( |$)'

LOCK_HELD=0
STARTED_COLIMA=0
RESTORED_COLIMA=0
RESULTS=""
FREE_BEFORE=""
STEP_STATUS=""
STEP_DETAIL=""
LAST_OUT=""
LAST_RC=0
WORK_DIR=""

usage() {
  cat <<EOF
Usage: ${PROG} [--dry-run] <daily|weekly>

  -n, --dry-run   run the read-only checks, print the plan, change nothing
  -h, --help      print this help
EOF
}

log() {
  local line
  line="$(date '+%Y-%m-%dT%H:%M:%S%z') ${PROFILE:-init}: ${*}"
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  printf '%s\n' "${line}" >>"${LOG_FILE}" 2>/dev/null || true
}

log_block() {
  local line
  [ -n "${1}" ] || return 0
  while IFS= read -r line; do
    log "  ${line}"
  done <<<"${1}"
}

strip_ansi() {
  sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g'
}

with_timeout() {
  local secs="${1}" pid watcher rc=0
  shift
  "${@}" &
  pid=${!}
  (
    sleep "${secs}"
    pkill -TERM -P "${pid}" 2>/dev/null || true
    kill -TERM "${pid}" 2>/dev/null || true
    sleep 5
    pkill -KILL -P "${pid}" 2>/dev/null || true
    kill -KILL "${pid}" 2>/dev/null || true
  ) >/dev/null 2>&1 &
  watcher=${!}
  wait "${pid}" || rc=${?}
  pkill -P "${watcher}" 2>/dev/null || true
  kill "${watcher}" 2>/dev/null || true
  wait "${watcher}" 2>/dev/null || true
  return "${rc}"
}

# Tools managed by mise resolve through mise exec from the home directory, so a
# project-local mise.toml never changes the version a cleanup runs with.
mx() {
  if command -v mise >/dev/null 2>&1; then
    mise exec -- "${@}"
  else
    "${@}"
  fi
}

dk() {
  env -u DOCKER_HOST DOCKER_CONTEXT=colima docker "${@}"
}

busy() {
  pgrep -f -- "${1}" >/dev/null 2>&1
}

# exec_cmd <seconds> <command...>: sets LAST_OUT and LAST_RC, stdout and stderr merged.
# The output goes through a file so the exit code is the command's, not a pipe's.
exec_cmd() {
  local secs="${1}" outfile="${WORK_DIR}/exec.out"
  shift
  log "run: ${*}"
  with_timeout "${secs}" "${@}" >"${outfile}" 2>&1
  LAST_RC=${?}
  LAST_OUT="$(strip_ansi <"${outfile}")"
  log_block "${LAST_OUT}"
  log "exit: ${LAST_RC}"
  return "${LAST_RC}"
}

# run_cmd changes state, so a dry run only prints it.
run_cmd() {
  LAST_OUT=""
  LAST_RC=0
  if [ "${DRY_RUN}" = 1 ]; then
    log "dry-run: would run: ${*:2}"
    printf 'dry-run: would run: %s\n' "${*:2}" >&2
    return 0
  fi
  exec_cmd "${@}"
}

# run_ro only reads, so it runs even in a dry run and the plan comes from real data.
run_ro() {
  LAST_OUT=""
  LAST_RC=0
  exec_cmd "${@}"
}

last_line() {
  local text="${1}" line=""
  line="$(printf '%s\n' "${text}" | grep -v '^[[:space:]]*$' | grep -v '^mise WARN' | tail -n 1)"
  line="${line//|/ }"
  printf '%s' "${line:0:160}"
}

ok() {
  STEP_STATUS="ok"
  STEP_DETAIL="${1:-}"
}

fail() {
  STEP_STATUS="failed"
  STEP_DETAIL="${1:-}"
}

skip() {
  STEP_STATUS="skipped"
  STEP_DETAIL="${1:-}"
}

fail_from_run() {
  if [ "${LAST_RC}" = 143 ] || [ "${LAST_RC}" = 137 ]; then
    fail "timed out: $(last_line "${LAST_OUT}")"
  else
    fail "exit ${LAST_RC}: $(last_line "${LAST_OUT}")"
  fi
}

run_step() {
  local name="${1}" fn="${2}"
  STEP_STATUS="failed"
  STEP_DETAIL="step did not report a result"
  log "== ${name}"
  "${fn}"
  if [ "${DRY_RUN}" = 1 ] && [ "${STEP_STATUS}" = "ok" ]; then
    STEP_STATUS="dry-run"
  fi
  log "== ${name}: ${STEP_STATUS}: ${STEP_DETAIL}"
  RESULTS="${RESULTS}${name}|${STEP_STATUS}|${STEP_DETAIL}"$'\n'
}

# guarded <seconds> <busy-regex> <command...>
guarded() {
  local secs="${1}" re="${2}"
  shift 2
  if [ -n "${re}" ] && busy "${re}"; then
    skip "a conflicting process is running"
    return 0
  fi
  if run_cmd "${secs}" "${@}"; then
    ok "$(last_line "${LAST_OUT}")"
  else
    fail_from_run
  fi
}

free_kb() {
  df -k "${HOME}" 2>/dev/null | awk 'NR==2 {print $4}'
}

allocated_kb() {
  du -k "${1}" 2>/dev/null | awk '{print $1; exit}'
}

gib() {
  awk -v kb="${1:-0}" 'BEGIN {printf "%.1f GiB", kb / 1048576}'
}

release_lock() {
  if [ "${LOCK_HELD}" = 1 ]; then
    if [ "$(readlink "${LOCK_PATH}" 2>/dev/null || true)" = "${$}" ]; then
      rm -f "${LOCK_PATH}" 2>/dev/null || true
    fi
    LOCK_HELD=0
  fi
}

# The lock is a symlink whose target is the owner pid, so taking it and
# recording the owner are one atomic step. A lock whose owner is gone is
# renamed to a name only this run uses before it is removed.
acquire_lock() {
  local waited=0 owner claimed
  mkdir -p "$(dirname "${LOCK_PATH}")" 2>/dev/null || true
  while :; do
    if ln -s "${$}" "${LOCK_PATH}" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    owner="$(readlink "${LOCK_PATH}" 2>/dev/null || true)"
    if [ -n "${owner}" ] && ! kill -0 "${owner}" 2>/dev/null; then
      claimed="${LOCK_PATH}.stale.${$}"
      if mv "${LOCK_PATH}" "${claimed}" 2>/dev/null; then
        rm -f "${claimed}" 2>/dev/null || true
        log "removed a stale lock held by ${owner}"
        continue
      fi
    fi
    if [ "${waited}" -ge "${LOCK_WAIT_SECONDS}" ]; then
      return 1
    fi
    sleep "${LOCK_POLL_SECONDS}"
    waited=$((waited + LOCK_POLL_SECONDS))
  done
}

docker_restore() {
  local running
  if [ "${STARTED_COLIMA}" != 1 ] || [ "${RESTORED_COLIMA}" = 1 ]; then
    return 0
  fi
  RESTORED_COLIMA=1
  running="$(dk ps -q 2>/dev/null | grep -c . || true)"
  if [ "${running:-0}" -gt 0 ]; then
    log "colima was started by this run but ${running} containers are running now; leaving it up"
    COLIMA_NOTE="left running: ${running} containers appeared while the run was in progress"
    return 0
  fi
  log "stopping colima, which this run started"
  with_timeout "${TIMEOUT_SHORT}" colima stop >>"${LOG_FILE}" 2>&1 || COLIMA_NOTE="colima stop failed"
}
COLIMA_NOTE=""

cleanup_exit() {
  local code=${?}
  trap - EXIT
  docker_restore
  release_lock
  if [ -n "${WORK_DIR}" ]; then
    rm -rf "${WORK_DIR}" 2>/dev/null || true
  fi
  exit "${code}"
}

### daily and weekly steps

s_mise_cache_prune() { guarded "${TIMEOUT_SHORT}" "${RE_MISE}" mise cache prune; }
s_mise_cache_clear() { guarded "${TIMEOUT_SHORT}" "${RE_MISE}" mise cache clear; }
s_uv_cache_prune() { guarded "${TIMEOUT_SHORT}" "" uv cache prune; }
# uv takes the cache lock itself and waits for a running uv, so the timeout is
# the only guard it needs.
s_uv_cache_clean() { guarded "${TIMEOUT_SHORT}" "" uv cache clean; }
s_pnpm_store_prune() { guarded "${TIMEOUT_SHORT}" "${RE_PNPM}" mx pnpm store prune; }
s_bun_cache_prune() { guarded "${TIMEOUT_SHORT}" "${RE_BUN}" mx bun pm cache prune; }
s_brew_cleanup() { guarded "${TIMEOUT_LONG}" "${RE_BREW}" brew cleanup; }
s_go_clean() { guarded "${TIMEOUT_LONG}" "${RE_GO}" mx go clean -cache -modcache; }

### weekly: mise upgrade

s_mise_upgrade() {
  local plan tool failed=""
  if busy "${RE_MISE}"; then
    skip "a conflicting process is running"
    return 0
  fi
  # Skip the live upgrade when nothing would change, so the lock and the
  # autosync pull request stay quiet on a quiet week.
  if ! run_ro "${TIMEOUT_LONG}" mise upgrade --global --dry-run; then
    fail_from_run
    return 0
  fi
  plan="$(printf '%s\n' "${LAST_OUT}" | grep -E '^Would install ' || true)"
  if [ -z "${plan}" ]; then
    ok "already up to date"
    return 0
  fi
  UPGRADE_PLAN="$(printf '%s' "${plan}" | sed 's/^Would install //' | tr '\n' ',' | sed 's/,$//')"
  if [ "${DRY_RUN}" = 1 ]; then
    ok "would upgrade: ${UPGRADE_PLAN}"
    return 0
  fi
  if ! run_cmd "${TIMEOUT_LONG}" mise upgrade --global; then
    fail_from_run
    return 0
  fi
  # No rollback: the old versions stay for upgrade.prune_after, so a person
  # can pin them back by hand.
  if ! run_cmd "${TIMEOUT_SHORT}" mise doctor; then
    fail "upgraded (${UPGRADE_PLAN}) but mise doctor failed: $(last_line "${LAST_OUT}")"
    return 0
  fi
  for tool in ${VERIFY_TOOLS}; do
    if ! run_cmd "${TIMEOUT_SHORT}" mx "${tool}" --version; then
      failed="${failed} ${tool}"
    fi
  done
  if [ -n "${failed}" ]; then
    fail "upgraded (${UPGRADE_PLAN}) but --version failed for:${failed}"
    return 0
  fi
  UPGRADE_DONE=1
  ok "upgraded: ${UPGRADE_PLAN}"
}
UPGRADE_PLAN=""
UPGRADE_DONE=0

# The interactive mise wrapper in dot_zshrc hands changed files to autosync after
# an upgrade. A script does not go through that wrapper, so it makes the same call.
s_mise_autosync() {
  if [ "${UPGRADE_DONE}" != 1 ]; then
    skip "no verified upgrade to sync"
    return 0
  fi
  if ! command -v dotfiles-autosync.sh >/dev/null 2>&1; then
    skip "dotfiles-autosync.sh is not on PATH"
    return 0
  fi
  guarded "${TIMEOUT_LONG}" "" dotfiles-autosync.sh mise
}

### weekly: npx cache

npx_in_use_keys() {
  ps -axww -o command 2>/dev/null | grep -o '/_npx/[0-9a-f]\{16\}' | sed 's#/_npx/##' | sort -u
}

s_npx_cache() {
  local all in_use key keep=() remove=() total
  if ! run_ro "${TIMEOUT_SHORT}" mx npm cache npx ls; then
    fail_from_run
    return 0
  fi
  all="$(printf '%s\n' "${LAST_OUT}" | sed -n 's/^\([0-9a-f]\{16\}\):.*/\1/p')"
  in_use="$(npx_in_use_keys)"
  total=0
  while IFS= read -r key; do
    [ -n "${key}" ] || continue
    total=$((total + 1))
    if printf '%s\n' "${in_use}" | grep -qx "${key}"; then
      keep+=("${key}")
    else
      remove+=("${key}")
    fi
  done <<<"${all}"
  if [ "${#remove[@]}" -eq 0 ]; then
    ok "nothing to remove, ${#keep[@]} of ${total} in use"
    return 0
  fi
  if run_cmd "${TIMEOUT_SHORT}" mx npm cache npx rm "${remove[@]}"; then
    ok "$([ "${DRY_RUN}" = 1 ] && printf 'would remove' || printf 'removed') ${#remove[@]} of ${total} keys, kept ${#keep[@]} in use"
  else
    fail_from_run
  fi
}

### weekly: Docker and Colima

s_docker() {
  local was_running=1 before after reclaimed

  if busy "${RE_DOCKER}"; then
    skip "a docker build is running"
    return 0
  fi

  if ! colima status >/dev/null 2>&1; then
    was_running=0
  fi

  if [ "${DRY_RUN}" = 1 ]; then
    if [ "${was_running}" = 1 ]; then
      run_ro "${TIMEOUT_SHORT}" dk system df
      log "dry-run: colima is running; would prune and fstrim, then leave it running"
    else
      log "dry-run: colima is stopped; would start it, prune, fstrim, then stop it"
    fi
    run_cmd "${TIMEOUT_SHORT}" dk system prune -f
    run_cmd "${TIMEOUT_SHORT}" colima ssh -- sudo fstrim -a
    ok "dry-run plan only"
    return 0
  fi

  if [ "${was_running}" = 0 ]; then
    if ! run_cmd "${TIMEOUT_LONG}" colima start; then
      fail "colima start failed: $(last_line "${LAST_OUT}")"
      return 0
    fi
    STARTED_COLIMA=1
  fi

  if ! run_ro "${TIMEOUT_SHORT}" dk info; then
    fail "docker info failed: $(last_line "${LAST_OUT}")"
    docker_restore
    return 0
  fi

  # Inventory goes to the log only, so what a prune removed can be compared.
  run_ro "${TIMEOUT_SHORT}" dk ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' || true
  run_ro "${TIMEOUT_SHORT}" dk images || true
  run_ro "${TIMEOUT_SHORT}" dk volume ls || true
  run_ro "${TIMEOUT_SHORT}" dk system df -v || true

  before="$(allocated_kb "${COLIMA_DISK}")"

  if ! run_cmd "${TIMEOUT_LONG}" dk system prune -f; then
    fail "docker system prune failed: $(last_line "${LAST_OUT}")"
    docker_restore
    return 0
  fi
  reclaimed="$(printf '%s\n' "${LAST_OUT}" | sed -n 's/^Total reclaimed space: *//p' | tail -n 1)"

  if ! run_cmd "${TIMEOUT_LONG}" colima ssh -- sudo fstrim -a; then
    fail "pruned ${reclaimed:-unknown} but fstrim failed: $(last_line "${LAST_OUT}")"
    docker_restore
    return 0
  fi

  after="$(allocated_kb "${COLIMA_DISK}")"
  docker_restore
  ok "pruned ${reclaimed:-unknown}; datadisk ${before:+$(gib "${before}")} -> ${after:+$(gib "${after}")}${COLIMA_NOTE:+; ${COLIMA_NOTE}}"
}

### weekly: merged worktrees

# Paths that are the current directory of any running process. Without this
# list the guard cannot work, so an empty list stops the step.
collect_busy_cwds() {
  lsof -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | sort -u
}

path_in_use() {
  local target="${1}"
  awk -v p="${target}" '$0 == p || index($0, p "/") == 1 {found = 1; exit} END {exit !found}' "${CWD_FILE}"
}

canonical_dir() {
  (unset CDPATH && cd -P -- "${1}" 2>/dev/null && pwd -P)
}

repo_dirs() {
  local d count
  for d in "${GHQ_ROOT}"/*/*/*; do
    [ -d "${d}/.git" ] || continue
    count="$(git -C "${d}" worktree list --porcelain 2>/dev/null | grep -c '^worktree ' || true)"
    if [ "${count:-0}" -gt 1 ]; then
      printf '%s\n' "${d}"
    fi
  done
}

# One repository: list what gtr would remove, drop what a process is using,
# then remove the rest the way git gtr does.
clean_repo() {
  local repo="${1}" out rc line branch path canon sha dirty
  local removed=0 busy_n=0 failed_n=0 candidates=0

  # An empty directory stands in for gtr's worktrees directory. The merged
  # cleanup reads Git's own worktree list, but gtr returns early when the
  # configured directory does not exist.
  cd "${repo}" || return 0
  run_ro "${TIMEOUT_WORKTREE}" git gtr clean --merged --dry-run
  rc=${LAST_RC}
  out="${LAST_OUT}"
  log "repo ${repo}: gtr dry-run exit ${rc}"
  if ! printf '%s\n' "${out}" | grep -q 'Dry run complete'; then
    REPO_SKIPPED="${REPO_SKIPPED}${repo}: $(last_line "${out}")"$'\n'
    return 0
  fi

  while IFS= read -r line; do
    case "${line}" in
      *"Would remove: "*) ;;
      *) continue ;;
    esac
    if [[ ! "${line}" =~ Would\ remove:\ (.+)\ \((/.*)\)$ ]]; then
      continue
    fi
    branch="${BASH_REMATCH[1]}"
    path="${BASH_REMATCH[2]}"
    candidates=$((candidates + 1))
    canon="$(canonical_dir "${path}" || true)"
    if [ -z "${canon}" ]; then
      canon="${path}"
    fi
    if path_in_use "${canon}" || path_in_use "${path}"; then
      busy_n=$((busy_n + 1))
      log "keep ${branch} (${path}): a running process uses it"
      continue
    fi
    sha="$(git -C "${path}" rev-parse HEAD 2>/dev/null || echo unknown)"
    dirty="$(git -C "${path}" status --porcelain 2>/dev/null | grep -c . || true)"
    if [ "${DRY_RUN}" = 1 ]; then
      log "dry-run: would remove ${branch} (${path}) sha=${sha} dirty_entries=${dirty}"
      removed=$((removed + 1))
      continue
    fi
    # The log line is the way back: git branch <name> <sha> restores the branch.
    log "remove ${branch} (${path}) sha=${sha} dirty_entries=${dirty}"
    if run_cmd "${TIMEOUT_LONG}" git gtr rm "${branch}" --force --yes --delete-branch; then
      removed=$((removed + 1))
    else
      failed_n=$((failed_n + 1))
      log "failed to remove ${branch} (${path})"
    fi
  done <<<"${out}"

  TOTAL_REMOVED=$((TOTAL_REMOVED + removed))
  TOTAL_BUSY=$((TOTAL_BUSY + busy_n))
  TOTAL_FAILED=$((TOTAL_FAILED + failed_n))
  if [ "${candidates}" -gt 0 ]; then
    REPO_LINES="${REPO_LINES}${repo##*/}: removed ${removed}, in use ${busy_n}, failed ${failed_n}"$'\n'
  fi
}
TOTAL_REMOVED=0
TOTAL_BUSY=0
TOTAL_FAILED=0
REPO_LINES=""
REPO_SKIPPED=""
CWD_FILE=""

s_worktrees() {
  local repo repos n=0 skipped_n detail
  CWD_FILE="${WORK_DIR}/cwds"
  collect_busy_cwds >"${CWD_FILE}"
  if ! grep -q . "${CWD_FILE}"; then
    fail "cannot list process working directories; refusing to remove worktrees without the in-use guard"
    return 0
  fi
  mkdir -p "${WORK_DIR}/gtr"
  export GTR_WORKTREES_DIR="${WORK_DIR}/gtr"
  repos="$(repo_dirs)"
  while IFS= read -r repo; do
    [ -n "${repo}" ] || continue
    n=$((n + 1))
    clean_repo "${repo}"
  done <<<"${repos}"
  cd "${HOME}" || true
  skipped_n="$(printf '%s' "${REPO_SKIPPED}" | grep -c . || true)"
  log_block "${REPO_LINES}"
  log_block "${REPO_SKIPPED}"
  detail="${n} repos; removed ${TOTAL_REMOVED}, in use ${TOTAL_BUSY}, failed ${TOTAL_FAILED}, repos skipped ${skipped_n}"
  if [ "${TOTAL_FAILED}" -gt 0 ]; then
    fail "${detail}"
  else
    ok "${detail}"
  fi
}

### report

print_report() {
  local free_after failed_n line name status detail
  free_after="$(free_kb)"
  failed_n="$(printf '%s' "${RESULTS}" | awk -F'|' '$2 == "failed"' | grep -c . || true)"
  if [ "${failed_n}" -gt 0 ]; then
    printf 'FAILED: %s of the steps failed, see the table.\n\n' "${failed_n}"
  fi
  printf '# %s %s%s\n\n' "${PROG}" "${PROFILE}" "$([ "${DRY_RUN}" = 1 ] && printf ' (dry-run)')"
  printf '| Step | Result | Detail |\n|---|---|---|\n'
  while IFS='|' read -r name status detail; do
    [ -n "${name}" ] || continue
    printf '| %s | %s | %s |\n' "${name}" "${status}" "${detail}"
  done <<<"${RESULTS}"
  printf '\nFree space on the home volume: %s -> %s\n' "$(gib "${FREE_BEFORE}")" "$(gib "${free_after}")"
  if [ -n "${REPO_LINES}" ]; then
    printf '\nWorktrees by repository:\n\n'
    while IFS= read -r line; do
      [ -n "${line}" ] && printf -- '- %s\n' "${line}"
    done <<<"${REPO_LINES}"
  fi
  if [ -n "${REPO_SKIPPED}" ]; then
    printf '\nRepositories skipped for worktree cleanup:\n\n'
    while IFS= read -r line; do
      [ -n "${line}" ] && printf -- '- %s\n' "${line}"
    done <<<"${REPO_SKIPPED}"
  fi
  printf '\nLog: %s\n' "${LOG_FILE}"
  log "report: free ${FREE_BEFORE}KB -> ${free_after}KB, failed steps ${failed_n}"
  [ "${failed_n}" -eq 0 ]
}

main() {
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      -n | --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      daily | weekly)
        if [ -n "${PROFILE}" ]; then
          printf '%s\n' "${PROG}: only one profile may be given" >&2
          usage >&2
          exit 2
        fi
        PROFILE="${1}"
        ;;
      *)
        printf '%s\n' "${PROG}: unknown argument: ${1}" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  if [ -z "${PROFILE}" ]; then
    printf '%s\n' "${PROG}: a profile is required" >&2
    usage >&2
    exit 2
  fi

  PATH="${PATH:-}:/opt/homebrew/bin:/opt/homebrew/sbin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export PATH
  cd "${HOME}" || exit 1

  trap cleanup_exit EXIT
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${PROG}.XXXXXX")" || exit 1

  if [ "${DRY_RUN}" = 0 ]; then
    acquire_lock || {
      printf 'FAILED: another %s run holds the lock\n' "${PROG}"
      log "timed out waiting for the lock"
      exit 1
    }
  fi

  # Keep the Mac awake for as long as this script runs.
  if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i -w "${$}" >/dev/null 2>&1 &
  fi

  log "start profile=${PROFILE} dry_run=${DRY_RUN}"
  FREE_BEFORE="$(free_kb)"

  if [ "${PROFILE}" = daily ]; then
    run_step "mise cache prune" s_mise_cache_prune
    run_step "uv cache prune" s_uv_cache_prune
    run_step "pnpm store prune" s_pnpm_store_prune
    run_step "bun pm cache prune" s_bun_cache_prune
    run_step "brew cleanup" s_brew_cleanup
  else
    run_step "mise upgrade --global" s_mise_upgrade
    run_step "mise autosync" s_mise_autosync
    run_step "mise cache clear" s_mise_cache_clear
    run_step "uv cache clean" s_uv_cache_clean
    run_step "pnpm store prune" s_pnpm_store_prune
    run_step "bun pm cache prune" s_bun_cache_prune
    run_step "brew cleanup" s_brew_cleanup
    run_step "go clean -cache -modcache" s_go_clean
    run_step "npm cache npx rm" s_npx_cache
    run_step "docker and colima" s_docker
    run_step "merged worktrees" s_worktrees
  fi

  print_report
  exit $?
}

main "${@}"
