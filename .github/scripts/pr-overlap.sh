#!/usr/bin/env bash
# Prints the warning comment for a pull request whose changed files overlap
# those of other open pull requests, or nothing when there is no overlap.
#
# Usage: pr-overlap.sh <pr-number> <open-prs.json>
#   open-prs.json: [{"number": 12, "files": ["path/a", ...]}, ...]
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: pr-overlap.sh <pr-number> <open-prs.json>" >&2
  exit 2
fi

pr=$1
prs_file=$2

jq -r --argjson pr "${pr}" '
  (map(select(.number == $pr)) | first | .files // [] | unique) as $mine
  | [ .[]
      | select(.number != $pr)
      | { number, shared: ([.files[] | select(IN($mine[]))] | unique) }
      | select(.shared | length > 0) ]
  | sort_by(.number)
  | if length == 0 then empty else
      "<!-- pr-overlap -->",
      "### Files also changed by other open PRs",
      "",
      "Merging one of these PRs may conflict with the other. This warning does not block merging.",
      "",
      (.[] | "- #\($pr) and #\(.number) both change:", (.shared[] | "  - `\(.)`"))
    end
' "${prs_file}"
