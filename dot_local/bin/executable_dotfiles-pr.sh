#!/bin/bash
# dotfiles-pr.sh: turn uncommitted chezmoi source changes into a pull request.
# Do:   branch off origin/main, commit, push, open the PR
#       --finish: switch main, pull --ff-only, chezmoi apply
# Need: the chezmoi source synced with origin/main

set -euo pipefail

PROG="dotfiles-pr"
BASE_BRANCH="main"
SOURCE=""

usage() {
  cat <<EOF
Usage: ${PROG} <commit message>
       ${PROG} --finish

Commit the uncommitted changes in the chezmoi source and open a pull request
against ${BASE_BRANCH}. Run chezmoi edit, add, or re-add first.

After the PR merges, ${PROG} --finish switches the source to ${BASE_BRANCH},
fast-forwards it, and runs chezmoi apply.

On ${BASE_BRANCH} it creates a chore/dotfiles-* branch. On such a branch it adds
to the same pull request.
EOF
}

fail() {
  printf '%s: %s\n' "${PROG}" "${*}" >&2
  exit 1
}

resolve_source() {
  SOURCE="$(chezmoi source-path 2>/dev/null)" || fail "cannot resolve the chezmoi source directory"
  if [ -z "${SOURCE}" ]; then
    fail "chezmoi returned an empty source directory"
  fi
  SOURCE="$(git -C "${SOURCE}" rev-parse --show-toplevel 2>/dev/null)" ||
    fail "chezmoi source is not a git worktree"
}

finish_source() {
  command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is not in PATH"
  command -v git >/dev/null 2>&1 || fail "git is not in PATH"

  resolve_source
  local source="${SOURCE}"

  git -C "${source}" switch "${BASE_BRANCH}"
  git -C "${source}" pull --ff-only
  chezmoi apply
}

main() {
  local message=""
  local finish=""
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage
        exit 0
        ;;
      --finish)
        finish=1
        shift
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
  if [ -n "${finish}" ]; then
    finish_source
    return 0
  fi
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

  resolve_source
  local source="${SOURCE}"

  local current
  current="$(git -C "${source}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [ -z "${current}" ]; then
    fail "the source is on a detached HEAD"
  fi

  local branch="${current}"
  if [ "${current}" = "${BASE_BRANCH}" ]; then
    if [ -z "$(git -C "${source}" status --porcelain)" ]; then
      fail "nothing to commit; edit a file and run chezmoi edit, add, or re-add first"
    fi
    git -C "${source}" fetch --quiet origin "${BASE_BRANCH}" || fail "git fetch failed"
    if [ "$(git -C "${source}" rev-parse HEAD)" != "$(git -C "${source}" rev-parse "origin/${BASE_BRANCH}")" ]; then
      fail "local ${BASE_BRANCH} is not at origin/${BASE_BRANCH}; run 'git -C ${source} pull --ff-only' first"
    fi
    branch="chore/dotfiles-$(date +%Y%m%d-%H%M%S)"
    git -C "${source}" switch --quiet -c "${branch}" || fail "cannot create branch ${branch}"
  elif [[ "${current}" != chore/dotfiles-* ]]; then
    fail "the source is on '${current}'; switch to '${BASE_BRANCH}' to start a PR branch, or use one named chore/dotfiles-*"
  else
    git -C "${source}" fetch --quiet origin "${BASE_BRANCH}" || fail "git fetch failed"
    if [ -z "$(git -C "${source}" status --porcelain)" ] &&
      [ "$(git -C "${source}" rev-list --count "origin/${BASE_BRANCH}..HEAD")" -eq 0 ]; then
      fail "nothing to commit; nothing to deliver on ${branch}"
    fi
  fi

  if [ -n "$(git -C "${source}" status --porcelain)" ]; then
    git -C "${source}" add --all || fail "git add failed"
    git -C "${source}" commit --quiet -m "${message}" || fail "git commit failed"
  fi
  git -C "${source}" push --quiet --set-upstream origin "${branch}" ||
    fail "git push failed; commit kept on ${branch}. Retry: git -C ${source} push -u origin ${branch}"

  local url
  url="$(cd "${source}" && gh pr view --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || true)"
  if [ -z "${url}" ]; then
    url="$(cd "${source}" && gh pr create --fill --base "${BASE_BRANCH}" --head "${branch}")" ||
      fail "pull request creation failed; commit kept on ${branch}. Retry: (cd ${source} && gh pr create --fill --base ${BASE_BRANCH} --head ${branch})"
  fi

  printf '%s\n' "${url}"
  printf 'Next: merge the pull request, then run:\n'
  printf '  %s --finish\n' "${PROG}"
}

main "${@}"
