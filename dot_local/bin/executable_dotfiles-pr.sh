#!/bin/bash
# dotfiles-pr.sh: turn uncommitted chezmoi source changes into a pull request.
# Do:   branch off origin/main, commit, push, open the PR
# Need: the chezmoi source synced with origin/main

set -euo pipefail

PROG="dotfiles-pr"
BASE_BRANCH="main"

usage() {
  cat <<EOF
Usage: ${PROG} <commit message>

Commit the uncommitted changes in the chezmoi source on a new branch and open a
pull request against ${BASE_BRANCH}. Run chezmoi edit, add, or re-add first.

The source stays on the new branch. After the PR merges, switch back and pull.
EOF
}

fail() {
  printf '%s: %s\n' "${PROG}" "${*}" >&2
  exit 1
}

main() {
  local message=""
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        fail "unknown option: ${1}"
        ;;
      *)
        message="${1}"
        shift
        break
        ;;
    esac
  done
  if [ -z "${message}" ]; then
    usage >&2
    exit 2
  fi
  if [ ${#} -gt 0 ]; then
    fail "one commit message only"
  fi

  command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is not in PATH"
  command -v git >/dev/null 2>&1 || fail "git is not in PATH"
  command -v gh >/dev/null 2>&1 || fail "gh is not in PATH"

  local source
  source="$(chezmoi source-path 2>/dev/null)" || fail "cannot resolve the chezmoi source directory"
  if [ -z "${source}" ]; then
    fail "chezmoi returned an empty source directory"
  fi
  source="$(git -C "${source}" rev-parse --show-toplevel 2>/dev/null)" ||
    fail "chezmoi source is not a git worktree"

  if [ -z "$(git -C "${source}" status --porcelain)" ]; then
    fail "nothing to commit; edit a file and run chezmoi edit, add, or re-add first"
  fi

  local current
  current="$(git -C "${source}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [ -z "${current}" ]; then
    fail "the source is on a detached HEAD"
  fi

  local branch="${current}"
  if [ "${current}" = "${BASE_BRANCH}" ]; then
    git -C "${source}" fetch --quiet origin "${BASE_BRANCH}" || fail "git fetch failed"
    if [ "$(git -C "${source}" rev-parse HEAD)" != "$(git -C "${source}" rev-parse "origin/${BASE_BRANCH}")" ]; then
      fail "local ${BASE_BRANCH} is not at origin/${BASE_BRANCH}; run 'git -C ${source} pull --ff-only' first"
    fi
    branch="chore/dotfiles-$(date +%Y%m%d-%H%M%S)"
    git -C "${source}" switch --quiet -c "${branch}" || fail "cannot create branch ${branch}"
  fi

  git -C "${source}" add --all || fail "git add failed"
  git -C "${source}" commit --quiet -m "${message}" || fail "git commit failed"
  git -C "${source}" push --quiet --set-upstream origin "${branch}" ||
    fail "git push failed; commit kept on ${branch}"

  local url
  url="$(cd "${source}" && gh pr create --fill --base "${BASE_BRANCH}" --head "${branch}")" ||
    fail "pull request creation failed; commit kept on ${branch}"

  printf '%s\n' "${url}"
  printf 'Next: merge the pull request, then run:\n'
  printf '  git -C %q switch %s && git -C %q pull --ff-only\n' "${source}" "${BASE_BRANCH}" "${source}"
}

main "${@}"
