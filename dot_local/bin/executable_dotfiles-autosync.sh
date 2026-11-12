#!/bin/bash
# dotfiles-autosync.sh: one scope, apm | mise | nvim
# Do:   chezmoi re-add scope targets into a temporary worktree of origin/main, commit only on change
# Stop: origin/main changed a file the sync would write since the local base; a person pulls and applies
# Ship: push chore/autosync, then open or update its PR; a person merges it
# Need: nothing from the source checkout; it may be on any branch and dirty

set -euo pipefail

PROG="dotfiles-autosync"
BASE_BRANCH="main"
AUTOSYNC_BRANCH="chore/autosync"
SCOPE=""
DRY_RUN=0

SOURCE_DIR=""
WORKTREE_DIR=""
ORIGINAL_DIR="${PWD}"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
LOG_FILE="${LOG_DIR}/${PROG}.log"
LOCK_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/${PROG}.lock"
LOCK_STALE_SECONDS=900
LOCK_WAIT_SECONDS=600
LOCK_POLL_SECONDS=2
TIMEOUT_NETWORK=120
TIMEOUT_GH=60
TIMEOUT_MISE=600

LOCK_HELD=0
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
  # The zsh wrapper keeps this script's stderr and discards its stdout, so this
  # line is what puts the reason in the terminal that started the run.
  printf '%s\n' "${PROG}: ${message}" >&2
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
    owner="$(readlink "${LOCK_DIR}" 2>/dev/null || true)"
    if [ -z "${owner}" ] || [ "${owner}" = "${$}" ]; then
      rm -f "${LOCK_DIR}" 2>/dev/null || true
    fi
    LOCK_HELD=0
  fi
}

# The temporary worktree lives outside the source checkout, so every exit path,
# success or failure, has to take it away or it accumulates registrations that
# block the next run.
remove_worktree() {
  [ -n "${WORKTREE_DIR}" ] || return 0
  if [ -n "${SOURCE_DIR}" ]; then
    git -C "${SOURCE_DIR}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
    git -C "${SOURCE_DIR}" worktree prune >/dev/null 2>&1 || true
  fi
  rm -rf "${WORKTREE_DIR}" 2>/dev/null || true
  WORKTREE_DIR=""
}

restore() {
  local code=${?}
  trap - EXIT
  remove_worktree
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

path_age_seconds() {
  local path="${1}" mtime now
  # Stat the link itself, not its target, which is a pid and does not exist.
  # GNU stat takes -c; BSD stat takes -f. GNU stat also accepts -f but prints a
  # filesystem report, so only a plain integer counts as a time.
  mtime="$(stat -c %Y "${path}" 2>/dev/null || stat -f %m "${path}" 2>/dev/null || true)"
  case "${mtime}" in
    '' | *[!0-9]*) mtime="" ;;
  esac
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

# Two runs may both find the lock stale. The stale link is renamed to a name
# only this run uses, and only the run whose rename succeeds removes it, so a
# second run cannot delete a lock that a third run has just taken.
try_reclaim_lock() {
  local claimed="${LOCK_DIR}.stale.${$}"
  if [ -L "${LOCK_DIR}" ] && [ "$(lock_age_seconds)" -ge "${LOCK_STALE_SECONDS}" ]; then
    if mv "${LOCK_DIR}" "${claimed}" 2>/dev/null; then
      rm -f "${claimed}" 2>/dev/null || true
      return 0
    fi
  fi
  return 1
}

acquire_lock() {
  local waited=0
  mkdir -p "$(dirname "${LOCK_DIR}")" 2>/dev/null || true
  while :; do
    # A symlink is created atomically and its target is the owner, so taking
    # the lock and recording who holds it are one step. mkdir is not used: the
    # uutils mkdir on current Ubuntu returns success to two racing callers.
    if ln -s "${$}" "${LOCK_DIR}" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    if [ -L "${LOCK_DIR}" ] && [ "$(lock_age_seconds)" -ge "${LOCK_STALE_SECONDS}" ]; then
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

run_mise_lock() {
  command -v mise >/dev/null 2>&1 || fail "mise is not available in PATH"
  log "refreshing the global mise lock"
  if ! (cd "${ORIGINAL_DIR}" && with_timeout "${TIMEOUT_MISE}" mise lock --global >/dev/null 2>&1); then
    fail "mise lock --global failed"
  fi
}

# A fresh worktree of origin/main means the sync never checks out, rebases or
# resets anything the person is working in, and the commit is rebuilt from the
# live files on every run instead of accumulating on a long-lived branch.
prepare_worktree() {
  local base_ref="origin/${BASE_BRANCH}"
  command -v gh >/dev/null 2>&1 || fail "gh is not available in PATH"
  if ! with_timeout "${TIMEOUT_NETWORK}" git -C "${SOURCE_DIR}" fetch origin --prune --quiet; then
    fail "git fetch from origin failed"
  fi
  if ! git -C "${SOURCE_DIR}" rev-parse --verify --quiet "refs/remotes/${base_ref}" >/dev/null; then
    fail "cannot find ${base_ref} in the chezmoi source"
  fi
  # Registrations left by a killed run would otherwise pile up under .git/worktrees.
  git -C "${SOURCE_DIR}" worktree prune >/dev/null 2>&1 || true
  WORKTREE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${PROG}.XXXXXX")" || fail "cannot create a temporary directory"
  if ! git -C "${SOURCE_DIR}" worktree add --detach --quiet "${WORKTREE_DIR}" "${base_ref}"; then
    fail "cannot create a temporary worktree for ${base_ref}"
  fi
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

run_dry_run() {
  local target plan
  log "dry-run: scope=${SCOPE}"
  log "dry-run: source=${SOURCE_DIR}"
  log "dry-run: a temporary worktree of origin/${BASE_BRANCH}, delivered on ${AUTOSYNC_BRANCH}"
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

# Serves as a last check before force-pushing: anything on the sync branch that
# autosync did not create is a person's work, and overwriting it loses it.
autosync_branch_tip() {
  local total autosync
  if ! git rev-parse --verify --quiet "refs/remotes/origin/${AUTOSYNC_BRANCH}" >/dev/null; then
    return 0
  fi
  total="$(git rev-list --count "origin/${BASE_BRANCH}..origin/${AUTOSYNC_BRANCH}")" ||
    fail "cannot compare ${AUTOSYNC_BRANCH} with ${BASE_BRANCH}"
  autosync="$(git rev-list --count --grep='^chore(autosync): ' "origin/${BASE_BRANCH}..origin/${AUTOSYNC_BRANCH}")" ||
    fail "cannot inspect ${AUTOSYNC_BRANCH}"
  if [ "${total}" -ne "${autosync}" ]; then
    fail "origin/${AUTOSYNC_BRANCH} has commits autosync did not create; refusing to overwrite it"
  fi
  git rev-parse "refs/remotes/origin/${AUTOSYNC_BRANCH}"
}

# re-add copies the live file over the source, so syncing a file that origin
# changed since our base writes the older local target back and reverts that
# change. Refuse instead and let the live files catch up.
# Rename detection is off on both diffs: a rename reports only its destination,
# so an upstream rename would hide the old path that re-add recreates from the
# stale live file.
refuse_upstream_changes() {
  local synced upstream overlap
  synced="$(git diff --cached --name-only --no-renames)" ||
    fail "cannot list the staged sync paths"
  upstream="$(git diff --name-only --no-renames "refs/heads/${BASE_BRANCH}" "origin/${BASE_BRANCH}")" ||
    fail "cannot compare origin/${BASE_BRANCH} with ${BASE_BRANCH}"
  if [ -n "${synced}" ] && [ -n "${upstream}" ]; then
    overlap="$(printf '%s\n' "${synced}" | grep -Fxf <(printf '%s\n' "${upstream}") || true)"
    if [ -n "${overlap}" ]; then
      fail "refusing to sync $(printf '%s' "${overlap}" | tr '\n' ' ') because origin/${BASE_BRANCH} changed it since ${BASE_BRANCH}; pull and apply before syncing"
    fi
  fi
}

deliver() {
  cd "${WORKTREE_DIR}" || fail "cannot enter the temporary worktree"

  # apm writes its lockfile owner-only, and re-add would then rename the source
  # to private_apm.lock.yaml, a name Dependabot does not read.
  if [ "${SCOPE}" = apm ] && [ -f "${HOME}/.apm/apm.lock.yaml" ]; then
    chmod 644 "${HOME}/.apm/apm.lock.yaml" || fail "cannot make the apm lockfile readable"
  fi

  # --source keeps re-add writing into the temporary worktree, never into the
  # checkout the person is working in.
  if ! chezmoi --source "${WORKTREE_DIR}" re-add "${TARGETS[@]}" >/dev/null 2>&1; then
    fail "chezmoi re-add failed for scope ${SCOPE}"
  fi

  local stage_paths=()
  local target source_path
  for target in "${TARGETS[@]}"; do
    source_path="$(chezmoi --source "${WORKTREE_DIR}" source-path "${target}" 2>/dev/null || true)"
    if [ -n "${source_path}" ]; then
      stage_paths+=("${source_path}")
    fi
  done

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
    refuse_upstream_changes
    if ! git diff --cached --quiet; then
      git commit --quiet -m "$(commit_subject)" || fail "git commit failed"
      log "committed: $(commit_subject)"
    fi
  fi

  if [ "$(git rev-list --count "origin/${BASE_BRANCH}..HEAD")" -eq 0 ]; then
    log "no changes for scope ${SCOPE}; nothing to deliver"
    return 0
  fi

  local expected=""
  expected="$(autosync_branch_tip)"

  if [ -n "${expected}" ]; then
    if ! with_timeout "${TIMEOUT_NETWORK}" git push --quiet \
      --force-with-lease="refs/heads/${AUTOSYNC_BRANCH}:${expected}" \
      origin "HEAD:refs/heads/${AUTOSYNC_BRANCH}" >/dev/null 2>&1; then
      fail "git push to ${AUTOSYNC_BRANCH} failed"
    fi
  else
    if ! with_timeout "${TIMEOUT_NETWORK}" git push --quiet \
      origin "HEAD:refs/heads/${AUTOSYNC_BRANCH}" >/dev/null 2>&1; then
      fail "git push to ${AUTOSYNC_BRANCH} failed"
    fi
  fi

  PR_NUMBER="$(current_autosync_pr)"
  ensure_pull_request

  log "opened or updated PR #${PR_NUMBER}; waiting for a person to merge it"
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

  acquire_lock || fail "timed out waiting for another autosync run"

  if [ "${SCOPE}" = "mise" ]; then
    run_mise_lock
  fi

  prepare_worktree
  deliver
  release_lock
  exit 0
}

main "${@}"
