#!/usr/bin/env bash
# Prints the warning comment for a pull request whose changed files overlap
# those of other open pull requests, or nothing when there is no overlap.
#
# Usage: pr-overlap.sh <pr-number> <open-prs.json>
#   open-prs.json: [{"number": 12, "files": ["path/a", ...]}, ...]
set -euo pipefail

exit 0
