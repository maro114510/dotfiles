#!/usr/bin/env bats
#
# Verifies the two scripts behind the issue-size workflow: issue-size-decide.sh,
# which turns the decision model's answer into one size label, and
# issue-size-apply.sh, which writes that label to the Issue without touching
# any other label.
#
# Usage: bats .github/testdata/issue-size.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  decide="${repo_root}/.github/scripts/issue-size-decide.sh"
  apply="${repo_root}/.github/scripts/issue-size-apply.sh"
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin"
  export GH_LOG="${sandbox}/gh.log"
  export GH_LABELS_FILE="${sandbox}/labels.json"
  export PATH="${sandbox}/bin:${PATH}"
  : >"${GH_LOG}"

  # A fake gh that prints the Issue's label names, one per line, from
  # GH_LABELS_FILE, as the real call does with --jq '.[].name', and records
  # every call.
  cat >"${sandbox}/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GH_LOG}"
case "$*" in
  *"--method GET"*"/labels"*) jq -r '.[]' "${GH_LABELS_FILE}" ;;
esac
EOF
  chmod +x "${sandbox}/bin/gh"
}

teardown() {
  rm -rf "${sandbox}"
}

answer() {
  printf '%s\n' "$1" >"${sandbox}/answer.json"
  printf '%s\n' "${sandbox}/answer.json"
}

score_answer() {
  answer "{\"model\":\"jev-1.14.0\",\"answers\":{\"size\":{\"type\":\"score\",\"score\":$1,\"confidence\":$2}}}"
}

labels() {
  printf '%s\n' "$1" >"${GH_LABELS_FILE}"
}

# decide

@test "a low score at high confidence is small" {
  run "${decide}" "$(score_answer 0.4 0.8)"
  [ "$status" -eq 0 ]
  [ "$output" = "size/S" ]
}

@test "a middle score at high confidence is medium" {
  run "${decide}" "$(score_answer 1.0 0.8)"
  [ "$status" -eq 0 ]
  [ "$output" = "size/M" ]
}

@test "a high score at high confidence is large" {
  run "${decide}" "$(score_answer 1.8 0.8)"
  [ "$status" -eq 0 ]
  [ "$output" = "size/L" ]
}

@test "the bucket edges follow the thresholds 0.67 and 1.33" {
  run "${decide}" "$(score_answer 0.67 0.9)"
  [ "$output" = "size/M" ]
  run "${decide}" "$(score_answer 1.33 0.9)"
  [ "$output" = "size/L" ]
}

@test "any score below confidence 0.5 is unknown" {
  run "${decide}" "$(score_answer 1.8 0.3)"
  [ "$status" -eq 0 ]
  [ "$output" = "size/?" ]
}

@test "confidence exactly 0.5 is trusted" {
  run "${decide}" "$(score_answer 0.2 0.5)"
  [ "$output" = "size/S" ]
}

@test "malformed JSON gives no label and exit 0" {
  run "${decide}" "$(answer 'not json')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing score gives no label and exit 0" {
  run "${decide}" "$(answer '{"answers":{"size":{"type":"score","confidence":0.9}}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a non-numeric score gives no label and exit 0" {
  run "${decide}" "$(answer '{"answers":{"size":{"score":"big","confidence":0.9}}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an error body from the API gives no label and exit 0" {
  run "${decide}" "$(answer '{"error":{"type":"rate_limit","message":"slow down"}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing answer file gives no label and exit 0" {
  run "${decide}" "${sandbox}/absent.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# apply

@test "a new Issue gets the size and the auto marker" {
  labels '["bug"]'
  run "${apply}" o/r 7 size/M
  [ "$status" -eq 0 ]
  grep -q -- 'labels\[\]=size/M' "${GH_LOG}"
  grep -q -- 'labels\[\]=size/auto' "${GH_LOG}"
  ! grep -q -- '--method DELETE' "${GH_LOG}"
}

@test "a changed size removes only the old machine size" {
  labels '["bug","size/S","size/auto"]'
  run "${apply}" o/r 7 size/L
  [ "$status" -eq 0 ]
  grep -q -- 'labels\[\]=size/L' "${GH_LOG}"
  grep -q -- '--method DELETE repos/o/r/issues/7/labels/size%2FS' "${GH_LOG}"
  ! grep -q -- 'labels/bug' "${GH_LOG}"
  ! grep -q -- 'labels/size%2Fauto' "${GH_LOG}"
}

@test "the same size writes nothing" {
  labels '["size/M","size/auto"]'
  run "${apply}" o/r 7 size/M
  [ "$status" -eq 0 ]
  ! grep -q -- '--method POST' "${GH_LOG}"
  ! grep -q -- '--method DELETE' "${GH_LOG}"
}

@test "a size set by hand, without the auto marker, is left unchanged" {
  labels '["size/L"]'
  run "${apply}" o/r 7 size/S
  [ "$status" -eq 0 ]
  ! grep -q -- '--method POST' "${GH_LOG}"
  ! grep -q -- '--method DELETE' "${GH_LOG}"
}

@test "a label outside the fixed list is never written" {
  labels '[]'
  run "${apply}" o/r 7 'size/XL'
  [ "$status" -eq 0 ]
  ! grep -q -- '--method POST' "${GH_LOG}"
  run "${apply}" o/r 7 'bug'
  ! grep -q -- '--method POST' "${GH_LOG}"
}

@test "an empty label writes nothing" {
  labels '["size/S","size/auto"]'
  run "${apply}" o/r 7 ''
  [ "$status" -eq 0 ]
  ! grep -q -- '--method POST' "${GH_LOG}"
  ! grep -q -- '--method DELETE' "${GH_LOG}"
}

@test "a non-numeric Issue number is refused" {
  labels '[]'
  run "${apply}" o/r '7;rm' size/S
  [ "$status" -ne 0 ]
  ! grep -q -- '--method POST' "${GH_LOG}"
}

@test "the whole label set is never replaced" {
  labels '["bug","size/S","size/auto"]'
  run "${apply}" o/r 7 size/M
  ! grep -q -- '--method PUT' "${GH_LOG}"
  ! grep -q -- '--method PATCH' "${GH_LOG}"
}
