#!/usr/bin/env bash
# Prints the size label for an Issue from the decision model's answer, or
# nothing when the answer is missing, malformed, or not a score.
#
# Usage: issue-size-decide.sh <answer.json>
#   answer.json: the body the System One API returned for a request whose
#   question id is "size", a Score with three levels: small, medium, large.
#
# The score runs from 0 to 2. Below 0.67 is size/S, below 1.33 is size/M, and
# the rest is size/L; these edges come from a trial on 302 closed Issues.
# Below confidence 0.5 the label is size/?, so the model never guesses.
# Always exits 0, so a bad answer never fails the run; it only writes nothing.
set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: issue-size-decide.sh <answer.json>" >&2
  exit 2
fi

jq -r '
  .answers.size as $a
  | if ($a.score | type) == "number" and ($a.confidence | type) == "number" then
      if $a.confidence < 0.5 then "size/?"
      elif $a.score < 0.67 then "size/S"
      elif $a.score < 1.33 then "size/M"
      else "size/L" end
    else empty end
' "$1" 2>/dev/null || true
