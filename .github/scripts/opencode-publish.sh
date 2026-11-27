#!/usr/bin/env bash
# Applies a model-written patch to the checked-out commit and opens a draft
# pull request.
#
# Usage: opencode-publish.sh <owner/repo> <issue-number> <run-id[-attempt]> <run-url> <patch-file>
#
# Run it inside a checkout whose origin accepts the push. Nothing is pushed
# unless the patch applies and passes opencode-guard.sh, which must sit beside
# this script. The branch is named from the Issue, the run and its attempt, so a
# rerun never meets an earlier branch. The title and body are fixed text:
# nothing from the Issue or the model is copied into them.
#
# A pull request opened with the workflow token starts no pull_request checks,
# and a workflow_dispatch run on its branch does not count toward a required
# check. The body tells the owner to close and reopen it, which starts them.
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: opencode-publish.sh <owner/repo> <issue-number> <run-id[-attempt]> <run-url> <patch-file>" >&2
  exit 2
fi

repo=$1
issue=$2
run_id=$3
run_url=$4
patch=$5

if [[ ! "${issue}" =~ ^[0-9]+$ || ! "${run_id}" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
  echo "opencode-publish: the Issue number must be digits and the run id digits with an optional -attempt" >&2
  exit 2
fi

guard="$(dirname "${BASH_SOURCE[0]}")/opencode-guard.sh"

git apply --index --whitespace=nowarn "${patch}"
git diff --cached --name-only -z --no-renames HEAD | "${guard}" paths
"${guard}" staged

branch="opencode/issue-${issue}-${run_id}"
git switch -q -c "${branch}"
git -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -q -m "chore: OpenCode draft for Issue ${issue}"
git push -q origin "HEAD:refs/heads/${branch}"

base="$(gh api "repos/${repo}" --jq .default_branch)"
gh pr create --draft --repo "${repo}" --base "${base}" --head "${branch}" \
  --title "chore: OpenCode draft for Issue ${issue}" \
  --body "$(printf 'An OpenCode run drafted this change. Review it before merging.\n\nChecks do not run on a pull request that a workflow opens. Close and reopen this pull request to start its checks.\n\nRun: %s\n\nCloses #%s' "${run_url}" "${issue}")"
