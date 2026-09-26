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
CHECK_GRACE_ATTEMPTS=12
CHECK_GRACE_SLEEP=10

LOCK_HELD=0
SWITCHED=0
BRANCH_CREATED=0
NOTIFIED=0
PR_NUMBER=""

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
    rmdir "${LOCK_DIR}" 2>/dev/null || rm -rf "${LOCK_DIR}" 2>/dev/null || true
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

lock_age_seconds() {
  local mtime now
  mtime="$(stat -f %m "${LOCK_DIR}" 2>/dev/null || stat -c %Y "${LOCK_DIR}" 2>/dev/null || true)"
  if [ -z "${mtime}" ]; then
    printf '0'
    return 0
  fi
  now="$(date +%s)"
  printf '%s' "$((now - mtime))"
}

acquire_lock() {
  local waited=0 age
  mkdir -p "$(dirname "${LOCK_DIR}")" 2>/dev/null || true
  while :; do
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    if [ -d "${LOCK_DIR}" ]; then
      age="$(lock_age_seconds)"
      if [ "${age}" -ge "${LOCK_STALE_SECONDS}" ]; then
        log "removing stale lock, age ${age}s"
        rm -rf "${LOCK_DIR}" >/dev/null 2>&1 || true
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
  if ! (cd "${ORIGINAL_DIR}" && mise lock --global); then
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
  number="$(gh pr list --head "${AUTOSYNC_BRANCH}" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [ "${number}" = "null" ]; then
    number=""
  fi
  printf '%s' "${number}"
}

ensure_pull_request() {
  if [ -n "${PR_NUMBER}" ]; then
    return 0
  fi
  if gh pr create \
    --base "${BASE_BRANCH}" \
    --head "${AUTOSYNC_BRANCH}" \
    --title "$(commit_subject)" \
    --body "$(pr_body)" >/dev/null 2>&1; then
    PR_NUMBER="$(gh pr view "${AUTOSYNC_BRANCH}" --json number --jq '.number' 2>/dev/null || true)"
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
    names="$(gh pr checks "${PR_NUMBER}" --json name 2>/dev/null || true)"
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
  if ! gh pr checks "${PR_NUMBER}" --watch --fail-fast; then
    fail "CI checks failed for PR #${PR_NUMBER}; commit preserved on ${AUTOSYNC_BRANCH}"
  fi
}

merge_pull_request() {
  local state
  state="$(gh pr view "${PR_NUMBER}" --json state --jq '.state' 2>/dev/null || true)"
  if [ "${state}" = "MERGED" ]; then
    log "PR #${PR_NUMBER} already merged"
    return 0
  fi
  if ! gh pr merge "${PR_NUMBER}" --merge >/dev/null 2>&1; then
    state="$(gh pr view "${PR_NUMBER}" --json state --jq '.state' 2>/dev/null || true)"
    if [ "${state}" = "MERGED" ]; then
      log "PR #${PR_NUMBER} merged concurrently"
      return 0
    fi
    fail "gh pr merge failed for PR #${PR_NUMBER}"
  fi
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

  if [ -n "$(git status --porcelain)" ]; then
    git add -A || fail "git add failed"
    git commit --quiet -m "$(commit_subject)" || fail "git commit failed"
    log "committed: $(commit_subject)"
  fi

  if ! has_commits_since "refs/heads/${BASE_BRANCH}"; then
    log "no changes for scope ${SCOPE}; nothing to deliver"
    leave_autosync_branch
    return 0
  fi

  command -v gh >/dev/null 2>&1 || fail "gh is not available in PATH"

  git fetch origin --prune --quiet || fail "git fetch failed; commit preserved on ${AUTOSYNC_BRANCH}"

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

  git push --force-with-lease origin "${AUTOSYNC_BRANCH}" >/dev/null 2>&1 || fail "git push failed; commit preserved on ${AUTOSYNC_BRANCH}"

  return_to_main
  BRANCH_CREATED=0
  release_lock

  PR_NUMBER="$(current_autosync_pr)"
  ensure_pull_request
  wait_for_checks
  merge_pull_request

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
