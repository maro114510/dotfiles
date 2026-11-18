#!/usr/bin/env bats
# Tests the actual inline shell from the privileged reusable workflow.
# All GitHub commands are stubbed; no real PRs or tokens are used.

setup() {
  export TEST_TMP="$(mktemp -d)"
  export REPO="example/repo" PR="42" MERGE_METHOD="squash"
  export EXPECTED_HEAD="head-approved-by-dependabot-metadata" GH_TOKEN="fake"
  export GITHUB_RUN_ID="99999"
  export FAKE_CHECKS_JSON='[{"name":"build","bucket":"pass"}]'
  export FAKE_CHECKS_EXIT="0" FAKE_HEAD_AFTER_FIRST="" FAKE_BAD_HEAD=""
  export FAKE_COUNTER_FILE="$TEST_TMP/view-counter"

  # There is exactly one multiline run step. Preserve the original shell body.
  awk '
    /^        run: \|$/ { in_run=1; next }
    in_run && /^          / { sub(/^          /, ""); print; next }
    in_run && /^$/ { print ""; next }
    in_run { exit }
  ' "$BATS_TEST_DIRNAME/../workflows/reusable-dependabot-auto-merge.yml" > "$TEST_TMP/merge.sh"
  [ -s "$TEST_TMP/merge.sh" ]
  export PATH="$TEST_TMP/bin:$PATH"
  mkdir -p "$TEST_TMP/bin"
  cat > "$TEST_TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}/${2:-}" in
  pr/view)
    if [[ -n "${FAKE_BAD_HEAD:-}" ]]; then
      printf '%s\n' "$FAKE_BAD_HEAD"
    elif [[ -n "${FAKE_HEAD_AFTER_FIRST:-}" ]]; then
      seen="$(cat "$FAKE_COUNTER_FILE" 2>/dev/null || printf '0')"
      printf '%s' "$((seen + 1))" > "$FAKE_COUNTER_FILE"
      if (( seen == 0 )); then
        printf '%s\n' "$EXPECTED_HEAD"
      else
        printf '%s\n' "$FAKE_HEAD_AFTER_FIRST"
      fi
    else
      printf '%s\n' "$EXPECTED_HEAD"
    fi
    ;;
  pr/checks)
    printf '%s\n' "$FAKE_CHECKS_JSON"
    exit "$FAKE_CHECKS_EXIT"
    ;;
  pr/merge)
    printf 'MERGED: %s\n' "$*"
    ;;
  *)
    printf 'Unexpected gh call: %s\n' "$*" >&2
    exit 99
    ;;
esac
STUB
  chmod +x "$TEST_TMP/bin/gh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "inline workflow shell parses" {
  run bash -n "$TEST_TMP/merge.sh"
  [ "$status" -eq 0 ]
}

@test "a changed PR head is never merged" {
  export FAKE_BAD_HEAD="new-unchecked-head"
  run bash "$TEST_TMP/merge.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR head changed"* ]]
  [[ "$output" != *"MERGED:"* ]]
}

@test "a failing check blocks merge even with gh nonzero exit" {
  export FAKE_CHECKS_JSON='[{"name":"test","bucket":"fail"}]'
  export FAKE_CHECKS_EXIT="1"
  run bash "$TEST_TMP/merge.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed or was cancelled"* ]]
  [[ "$output" != *"MERGED:"* ]]
}

@test "invalid check API output fails visibly" {
  export FAKE_CHECKS_JSON="API unavailable"
  export FAKE_CHECKS_EXIT="1"
  run bash "$TEST_TMP/merge.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read a valid"* ]]
  [[ "$output" != *"MERGED:"* ]]
}

@test "an unrecognized check bucket cannot silently authorize merge" {
  export FAKE_CHECKS_JSON='[{"name":"test","bucket":"future-state"}]'
  run bash "$TEST_TMP/merge.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read a valid"* ]]
}

@test "all passing checks merge only the approved head after a stable set" {
  # Elide just the real-time 60-second wait; the complete command/guard path
  # runs against stubbed responses. Timing itself needs a real Actions E2E.
  sed 's/SECONDS - stable_since >= 60/SECONDS - stable_since >= 0/' \
    "$TEST_TMP/merge.sh" > "$TEST_TMP/fast-merge.sh"
  run bash "$TEST_TMP/fast-merge.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGED:"* ]]
  [[ "$output" == *"--match-head-commit $EXPECTED_HEAD"* ]]
}

@test "a changed head immediately before merge blocks it" {
  export FAKE_HEAD_AFTER_FIRST="unchecked-new-commit"
  sed 's/SECONDS - stable_since >= 60/SECONDS - stable_since >= 0/' \
    "$TEST_TMP/merge.sh" > "$TEST_TMP/fast-merge.sh"
  run bash "$TEST_TMP/fast-merge.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR head changed"* ]]
  [[ "$output" != *"MERGED:"* ]]
}
