#!/usr/bin/env bash
# Sets one machine size label on an Issue, without touching any other label.
#
# Usage: issue-size-apply.sh <owner/repo> <issue-number> <label>
#   label: one of size/S, size/M, size/L, size/?; anything else writes nothing.
#
# A machine size always comes with size/auto. An Issue that has a size label
# but no size/auto was sized by a person, so it is left as it is. Labels are
# added with POST and removed one at a time with DELETE; the whole label set
# is never replaced, so labels other writers set are never lost.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: issue-size-apply.sh <owner/repo> <issue-number> <label>" >&2
  exit 2
fi

repo=$1
issue=$2
want=$3
sizes=(size/S size/M size/L "size/?")

if [[ ! "${issue}" =~ ^[0-9]+$ ]]; then
  echo "issue-size-apply: not an Issue number: ${issue}" >&2
  exit 2
fi

allowed=false
for s in "${sizes[@]}"; do
  [[ "${want}" == "${s}" ]] && allowed=true
done
if [[ "${allowed}" != true ]]; then
  echo "issue-size-apply: no label written: '${want}' is not a size label" >&2
  exit 0
fi

# One name per line, so --paginate needs no merging of pages.
current="$(gh api --method GET "repos/${repo}/issues/${issue}/labels" --paginate --jq '.[].name')"
has() { grep -qxF -- "$1" <<<"${current}"; }

machine=false
has size/auto && machine=true
for s in "${sizes[@]}"; do
  if has "${s}" && [[ "${machine}" != true ]]; then
    echo "issue-size-apply: ${s} was set by a person; leaving it"
    exit 0
  fi
done

if has "${want}" && [[ "${machine}" == true ]]; then
  echo "issue-size-apply: already ${want}"
  exit 0
fi

gh api --method POST "repos/${repo}/issues/${issue}/labels" \
  -f "labels[]=${want}" -f "labels[]=size/auto" >/dev/null

for s in "${sizes[@]}"; do
  if [[ "${s}" != "${want}" ]] && has "${s}"; then
    encoded="$(jq -rn --arg s "${s}" '$s | @uri')"
    gh api --method DELETE "repos/${repo}/issues/${issue}/labels/${encoded}" >/dev/null
  fi
done
echo "issue-size-apply: set ${want}"
