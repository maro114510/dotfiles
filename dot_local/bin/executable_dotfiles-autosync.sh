#!/bin/bash
# dotfiles-autosync.sh: one scope, apm | mise | nvim
# Do:   chezmoi re-add scope targets, commit only on change
# Ship: push chore/autosync, reuse PR, watch CI, merge, fast-forward main
# Need: source checkout clean and on main

set -euo pipefail

PROG="dotfiles-autosync"
BASE_BRANCH="main"
AUTOSYNC_BRANCH="chore/autosync"
SCOPE=""
DRY_RUN=0

SOURCE_DIR=""
ORIGINAL_DIR="${PWD}"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
LOG_FILE="${LOG_DIR}/${PROG}.log"
LOCK_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/${PROG}.lock"
LOCK_STALE_SECONDS=900
LOCK_WAIT_SECONDS=600
LOCK_POLL_SECONDS=2
LOCK_RECLAIM_STALE_SECONDS=60
CHECK_GRACE_ATTEMPTS=12
CHECK_GRACE_SLEEP=10
TIMEOUT_NETWORK=120
TIMEOUT_GH=60
TIMEOUT_CI_WATCH=2700
TIMEOUT_MISE=600

LOCK_HELD=0
SWITCHED=0
BRANCH_CREATED=0
NOTIFIED=0
PR_NUMBER=""
PUSHED_SHA=""

TARGETS=()

usage() {
  cat <<EOF
Usage: ${PROG} [--dry-run] <apm|mise|nvim>

  -n, --dry-run   print the plan, change nothing
  -h, --help      print this help
EOF
}

log() {
  local line
  line="$(date '+%Y-%m-%dT%H:%M:%S%z') ${PROG}: ${*}"
  mkdir -p "${LOG_DIR}" 2>/dev/null || true
  printf '%s\n' "${line}" >>"${LOG_FILE}" 2>/dev/null || true
  if [ "${DRY_RUN}" = 1 ]; then
    printf '%s\n' "${line}"
  fi
}

with_timeout() {
  local secs="${1}" pid watcher rc=0
  shift
  "${@}" &
  pid=${!}
  (
    sleep "${secs}"
    kill -TERM "${pid}" 2>/dev/null || true
    sleep 5
    kill -KILL "${pid}" 2>/dev/null || true
  ) >/dev/null 2>&1 &
  watcher=${!}
  wait "${pid}" || rc=${?}
  kill "${watcher}" 2>/dev/null || true
  wait "${watcher}" 2>/dev/null || true
  return "${rc}"
}

notify() {
  local message="${1}" escaped
  NOTIFIED=1
  log "FAILURE: ${message}"
  if command -v osascript >/dev/null 2>&1; then
    escaped="${message//\"/}"
    osascript -e "display notification \"${escaped}\" with title \"${PROG}\"" >/dev/null 2>&1 || true
  fi
}

fail() {
  notify "${*}"
  exit 1
}

release_lock() {
  if [ "${LOCK_HELD}" = 1 ]; then
    local owner
    owner="$(cat "${LOCK_DIR}/owner" 2>/dev/null || true)"
    if [ -z "${owner}" ] || [ "${owner}" = "${$}" ]; then
      rm -rf "${LOCK_DIR}" 2>/dev/null || true
    fi
    LOCK_HELD=0
  fi
}

restore() {
  local code=${?}
  trap - EXIT
  if [ "${SWITCHED}" = 1 ] && [ -n "${SOURCE_DIR}" ]; then
    local current
    current="$(git -C "${SOURCE_DIR}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ "${current}" != "${BASE_BRANCH}" ]; then
      git -C "${SOURCE_DIR}" switch "${BASE_BRANCH}" --quiet >/dev/null 2>&1 || true
    fi
  fi
  release_lock
  if [ "${code}" -ne 0 ] && [ "${NOTIFIED}" = 0 ]; then
    notify "unexpected failure, exit ${code}"
    code=1
  fi
  exit "${code}"
}
trap restore EXIT

scope_targets() {
  case "${SCOPE}" in
    apm)
      printf '%s\n' \
        "${HOME}/.apm" \
        "${HOME}/.claude" \
        "${HOME}/.codex" \
        "${HOME}/.config/opencode"
      ;;
    mise)
      printf '%s\n' \
        "${HOME}/.config/mise/config.toml" \
        "${HOME}/.config/mise/mise.lock"
      ;;
    nvim)
      printf '%s\n' "${HOME}/.config/nvim/lazy-lock.json"
      ;;
  esac
}

commit_subject() {
  case "${SCOPE}" in
    apm) printf '%s' 'chore(autosync): sync apm-managed files' ;;
    mise) printf '%s' 'chore(autosync): sync mise global config and lock' ;;
    nvim) printf '%s' 'chore(autosync): sync nvim lazy-lock.json' ;;
  esac
}

pr_body() {
  local target
  printf 'scope: %s\n\ntargets:\n' "${SCOPE}"
  for target in "${TARGETS[@]}"; do
    printf -- '- %s\n' "${target}"
  done
}

scope_source_paths() {
  local target source
  for target in "${TARGETS[@]}"; do
    source="$(chezmoi source-path "${target}" 2>/dev/null || true)"
    if [ -n "${source}" ]; then
      printf '%s\n' "${source}"
    fi
  done
}

path_age_seconds() {
  local path="${1}" mtime now
  mtime="$(stat -f %m "${path}" 2>/dev/null || stat -c %Y "${path}" 2>/dev/null || true)"
  if [ -z "${mtime}" ]; then
    printf '0'
    return 0
  fi
  now="$(date +%s)"
  printf '%s' "$((now - mtime))"
}

lock_age_seconds() {
  path_age_seconds "${LOCK_DIR}"
}

try_reclaim_lock() {
  local reclaim="${LOCK_DIR}.reclaim" reclaimed=1
  if [ -d "${reclaim}" ] && [ "$(path_age_seconds "${reclaim}")" -ge "${LOCK_RECLAIM_STALE_SECONDS}" ]; then
    rm -rf "${reclaim}" 2>/dev/null || true
  fi
  if ! mkdir "${reclaim}" 2>/dev/null; then
    return 1
  fi
  if [ -d "${LOCK_DIR}" ] && [ "$(lock_age_seconds)" -ge "${LOCK_STALE_SECONDS}" ]; then
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
    reclaimed=0
  fi
  rmdir "${reclaim}" 2>/dev/null || rm -rf "${reclaim}" 2>/dev/null || true
  return "${reclaimed}"
}

acquire_lock() {
  local waited=0
  mkdir -p "$(dirname "${LOCK_DIR}")" 2>/dev/null || true
  while :; do
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      printf '%s\n' "${$}" >"${LOCK_DIR}/owner" 2>/dev/null || true
      LOCK_HELD=1
      return 0
    fi
    if [ -d "${LOCK_DIR}" ] && [ "$(lock_age_seconds)" -ge "${LOCK_STALE_SECONDS}" ]; then
      if try_reclaim_lock; then
        log "removed stale lock"
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

resolve_source() {
  command -v git >/dev/null 2>&1 || fail "git is not available in PATH"
  command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is not available in PATH"
  local resolved
  resolved="$(chezmoi source-path 2>/dev/null)" || fail "cannot resolve the chezmoi source directory"
  if [ -z "${resolved}" ]; then
    fail "chezmoi returned an empty source directory"
  fi
  SOURCE_DIR="$(git -C "${resolved}" rev-parse --show-toplevel 2>/dev/null)" || fail "chezmoi source is not a git worktree: ${resolved}"
}

guard() {
  local branch
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [ "${branch}" != "${BASE_BRANCH}" ]; then
    fail "source checkout is on '${branch:-detached HEAD}', expected '${BASE_BRANCH}'"
  fi
  if [ -n "$(git status --porcelain)" ]; then
    fail "source checkout has uncommitted changes; refusing to auto-sync"
  fi
}

run_mise_lock() {
  command -v mise >/dev/null 2>&1 || fail "mise is not available in PATH"
  log "refreshing the global mise lock"
  if ! (cd "${ORIGINAL_DIR}" && with_timeout "${TIMEOUT_MISE}" mise lock --global); then
    fail "mise lock --global failed"
  fi
}

switch_to_autosync() {
  if git show-ref --verify --quiet "refs/heads/${AUTOSYNC_BRANCH}"; then
    git switch "${AUTOSYNC_BRANCH}" --quiet
  elif git show-ref --verify --quiet "refs/remotes/origin/${AUTOSYNC_BRANCH}"; then
    git switch -c "${AUTOSYNC_BRANCH}" --track "origin/${AUTOSYNC_BRANCH}" --quiet
    BRANCH_CREATED=1
  else
    git switch -c "${AUTOSYNC_BRANCH}" "${BASE_BRANCH}" --quiet
    BRANCH_CREATED=1
  fi
  SWITCHED=1
}

return_to_main() {
  local current
  current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [ "${current}" != "${BASE_BRANCH}" ]; then
    git switch "${BASE_BRANCH}" --quiet || fail "failed to switch back to ${BASE_BRANCH}"
  fi
  SWITCHED=0
}

leave_autosync_branch() {
  return_to_main
  if [ "${BRANCH_CREATED}" = 1 ]; then
    git branch --delete --force "${AUTOSYNC_BRANCH}" >/dev/null 2>&1 || true
    BRANCH_CREATED=0
  fi
}

has_commits_since() {
  local count
  count="$(git rev-list --count "${1}..HEAD" 2>/dev/null)" || fail "cannot compare ${1} with HEAD"
  [ "${count}" -gt 0 ]
}

current_autosync_pr() {
  local number
  number="$(with_timeout "${TIMEOUT_GH}" gh pr list --head "${AUTOSYNC_BRANCH}" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [ "${number}" = "null" ]; then
    number=""
  fi
  printf '%s' "${number}"
}

ensure_pull_request() {
  if [ -n "${PR_NUMBER}" ]; then
    return 0
  fi
  if with_timeout "${TIMEOUT_GH}" gh pr create \
    --base "${BASE_BRANCH}" \
    --head "${AUTOSYNC_BRANCH}" \
    --title "$(commit_subject)" \
    --body "$(pr_body)" >/dev/null 2>&1; then
    PR_NUMBER="$(with_timeout "${TIMEOUT_GH}" gh pr view "${AUTOSYNC_BRANCH}" --json number --jq '.number' 2>/dev/null || true)"
  else
    # another run may have created it first
    PR_NUMBER="$(current_autosync_pr)"
  fi
  if [ -z "${PR_NUMBER}" ]; then
    fail "could not create or find the ${AUTOSYNC_BRANCH} pull request"
  fi
}

wait_for_checks() {
  local attempt=0 names
  while [ "${attempt}" -lt "${CHECK_GRACE_ATTEMPTS}" ]; do
    names="$(with_timeout "${TIMEOUT_GH}" gh pr checks "${PR_NUMBER}" --json name 2>/dev/null || true)"
    if [ -n "${names}" ] && [ "${names}" != "[]" ]; then
      break
    fi
    attempt=$((attempt + 1))
    if [ "${attempt}" -lt "${CHECK_GRACE_ATTEMPTS}" ]; then
      sleep "${CHECK_GRACE_SLEEP}"
    fi
  done
  if [ -z "${names}" ] || [ "${names}" = "[]" ]; then
    log "no CI checks reported for PR #${PR_NUMBER}; treating as passed"
    return 0
  fi
  if ! with_timeout "${TIMEOUT_CI_WATCH}" gh pr checks "${PR_NUMBER}" --watch --fail-fast; then
    fail "CI checks failed for PR #${PR_NUMBER}; commit preserved on ${AUTOSYNC_BRANCH}"
  fi
}

merge_pull_request() {
  local state head_sha
  state="$(with_timeout "${TIMEOUT_GH}" gh pr view "${PR_NUMBER}" --json state --jq '.state' 2>/dev/null || true)"
  if [ "${state}" = "MERGED" ]; then
    log "PR #${PR_NUMBER} already merged"
    return 0
  fi
  if with_timeout "${TIMEOUT_GH}" gh pr merge "${PR_NUMBER}" --merge --match-head-commit "${PUSHED_SHA}" >/dev/null 2>&1; then
    return 0
  fi
  state="$(with_timeout "${TIMEOUT_GH}" gh pr view "${PR_NUMBER}" --json state --jq '.state' 2>/dev/null || true)"
  if [ "${state}" = "MERGED" ]; then
    log "PR #${PR_NUMBER} merged concurrently"
    return 0
  fi
  head_sha="$(with_timeout "${TIMEOUT_GH}" gh pr view "${PR_NUMBER}" --json headRefOid --jq '.headRefOid' 2>/dev/null || true)"
  if [ -n "${head_sha}" ] && [ "${head_sha}" != "${PUSHED_SHA}" ]; then
    log "PR #${PR_NUMBER} head moved to ${head_sha}; handing off"
    return 2
  fi
  fail "gh pr merge failed for PR #${PR_NUMBER}"
}

run_dry_run() {
  local target plan
  log "dry-run: scope=${SCOPE}"
  log "dry-run: source=${SOURCE_DIR}"
  log "dry-run: branch=${AUTOSYNC_BRANCH}"
  for target in "${TARGETS[@]}"; do
    log "dry-run: target=${target}"
  done
  if [ "${SCOPE}" = "mise" ]; then
    log "dry-run: would run: mise lock --global"
  fi
  plan="$(chezmoi diff --no-pager --color=false "${TARGETS[@]}" 2>&1 | grep -v '^chezmoi: warning:' || true)"
  if [ -n "${plan}" ]; then
    log "dry-run: chezmoi diff shows changes re-add would sync:"
    printf '%s\n' "${plan}"
  else
    log "dry-run: no differences between target and source"
  fi
}

deliver() {
  if ! chezmoi re-add "${TARGETS[@]}" >/dev/null 2>&1; then
    fail "chezmoi re-add failed for scope ${SCOPE}"
  fi

  local stage_paths=()
  local source_path
  while IFS= read -r source_path; do
    if [ -n "${source_path}" ]; then
      stage_paths+=("${source_path}")
    fi
  done < <(scope_source_paths)

  local scope_changes
  if [ "${#stage_paths[@]}" -gt 0 ]; then
    scope_changes="$(git status --porcelain -- "${stage_paths[@]}")"
  else
    scope_changes="$(git status --porcelain)"
  fi

  if [ -n "${scope_changes}" ]; then
    if [ "${#stage_paths[@]}" -gt 0 ]; then
      git add -A -- "${stage_paths[@]}" || fail "git add failed"
    else
      git add -A || fail "git add failed"
    fi
    git commit --quiet -m "$(commit_subject)" || fail "git commit failed"
    log "committed: $(commit_subject)"
  fi

  if ! has_commits_since "refs/heads/${BASE_BRANCH}"; then
    log "no changes for scope ${SCOPE}; nothing to deliver"
    leave_autosync_branch
    return 0
  fi

  command -v gh >/dev/null 2>&1 || fail "gh is not available in PATH"

  if ! with_timeout "${TIMEOUT_NETWORK}" git fetch origin --prune --quiet; then
    fail "git fetch failed; commit preserved on ${AUTOSYNC_BRANCH}"
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/${AUTOSYNC_BRANCH}" &&
    ! git merge-base --is-ancestor "origin/${AUTOSYNC_BRANCH}" HEAD; then
    fail "origin/${AUTOSYNC_BRANCH} has commits not present locally; refusing to overwrite it"
  fi

  if ! git rebase --onto "origin/${BASE_BRANCH}" "refs/heads/${BASE_BRANCH}" >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1 || true
    fail "rebase onto origin/${BASE_BRANCH} failed; commit preserved on ${AUTOSYNC_BRANCH}"
  fi

  if ! has_commits_since "origin/${BASE_BRANCH}"; then
    log "commit already present in origin/${BASE_BRANCH}; nothing to deliver"
    leave_autosync_branch
    return 0
  fi

  if ! with_timeout "${TIMEOUT_NETWORK}" git push --force-with-lease origin "${AUTOSYNC_BRANCH}" >/dev/null 2>&1; then
    fail "git push failed; commit preserved on ${AUTOSYNC_BRANCH}"
  fi
  PUSHED_SHA="$(git rev-parse HEAD)"
  if [ -z "${PUSHED_SHA}" ]; then
    fail "could not resolve the pushed commit"
  fi

  return_to_main
  BRANCH_CREATED=0
  release_lock

  PR_NUMBER="$(current_autosync_pr)"
  ensure_pull_request
  wait_for_checks

  local merge_rc=0
  merge_pull_request || merge_rc=${?}
  if [ "${merge_rc}" -eq 2 ]; then
    log "handed off PR #${PR_NUMBER}; the run that pushed the newer head merges it"
    return 0
  fi
  if [ "${merge_rc}" -ne 0 ]; then
    return "${merge_rc}"
  fi

  acquire_lock || fail "timed out waiting for another autosync run"
  return_to_main
  if ! git pull --ff-only origin "${BASE_BRANCH}" --quiet; then
    notify "delivered PR #${PR_NUMBER} but could not fast-forward ${BASE_BRANCH}; resolve the local branch"
  fi
  release_lock

  log "delivered PR #${PR_NUMBER} and fast-forwarded ${BASE_BRANCH}"
  return 0
}

main() {
  local target

  while [ ${#} -gt 0 ]; do
    case "${1}" in
      -n | --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      apm | mise | nvim)
        if [ -n "${SCOPE}" ]; then
          printf '%s\n' "${PROG}: only one scope may be given" >&2
          usage >&2
          exit 2
        fi
        SCOPE="${1}"
        ;;
      *)
        printf '%s\n' "${PROG}: unknown argument: ${1}" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  if [ -z "${SCOPE}" ]; then
    printf '%s\n' "${PROG}: a scope is required" >&2
    usage >&2
    exit 2
  fi

  resolve_source

  while IFS= read -r target; do
    if [ -n "${target}" ]; then
      TARGETS+=("${target}")
    fi
  done < <(scope_targets)

  if [ "${DRY_RUN}" = 1 ]; then
    run_dry_run
    exit 0
  fi

  cd "${SOURCE_DIR}" || fail "cannot enter source directory: ${SOURCE_DIR}"

  acquire_lock || fail "timed out waiting for another autosync run"
  guard

  if [ "${SCOPE}" = "mise" ]; then
    run_mise_lock
  fi

  switch_to_autosync

  deliver
  release_lock
  exit 0
}

main "${@}"
