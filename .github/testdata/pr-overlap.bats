#!/usr/bin/env bats
#
# Verifies the overlap computation behind the pr-overlap workflow: which other
# open pull requests share changed files with a given one, and the warning
# comment that names them.
#
# Usage: bats .github/testdata/pr-overlap.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  script="${repo_root}/.github/scripts/pr-overlap.sh"
  sandbox="$(mktemp -d)"
}

teardown() {
  rm -rf "${sandbox}"
}

open_prs() {
  printf '%s\n' "$1" >"${sandbox}/prs.json"
  printf '%s\n' "${sandbox}/prs.json"
}

@test "a PR sharing no file with another open PR gets no warning" {
  prs=$(open_prs '[
    {"number": 10, "files": ["dot_zshrc"]},
    {"number": 11, "files": ["dot_vimrc"]}
  ]')

  run "${script}" 11 "${prs}"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a PR sharing a file with an older open PR gets a warning naming both PRs and the file" {
  prs=$(open_prs '[
    {"number": 10, "files": ["dot_zshrc", "dot_tmux.conf"]},
    {"number": 11, "files": ["dot_zshrc", "dot_vimrc"]}
  ]')

  run "${script}" 11 "${prs}"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "<!-- pr-overlap -->" ]
  [[ "$output" == *"- #11 and #10 both change:"* ]]
  [[ "$output" == *'  - `dot_zshrc`'* ]]
}

@test "the warning lists only the shared files, not the PRs' other files" {
  prs=$(open_prs '[
    {"number": 10, "files": ["dot_zshrc", "dot_tmux.conf"]},
    {"number": 11, "files": ["dot_zshrc", "dot_vimrc"]}
  ]')

  run "${script}" 11 "${prs}"

  [[ "$output" != *"dot_tmux.conf"* ]]
  [[ "$output" != *"dot_vimrc"* ]]
}

@test "each overlapping PR is listed with its own shared files in ascending PR order" {
  prs=$(open_prs '[
    {"number": 12, "files": ["dot_vimrc"]},
    {"number": 9, "files": ["dot_zshrc"]},
    {"number": 13, "files": ["dot_zshrc", "dot_vimrc"]},
    {"number": 10, "files": ["README.md"]}
  ]')

  run "${script}" 13 "${prs}"

  expected_list='- #13 and #9 both change:
  - `dot_zshrc`
- #13 and #12 both change:
  - `dot_vimrc`'
  [ "$status" -eq 0 ]
  [[ "$output" == *"${expected_list}"* ]]
  [[ "$output" != *"#10"* ]]
}

@test "shared files of one PR are listed once each in sorted order" {
  prs=$(open_prs '[
    {"number": 10, "files": ["dot_zshrc", "dot_vimrc", "dot_vimrc"]},
    {"number": 11, "files": ["dot_zshrc", "dot_vimrc"]}
  ]')

  run "${script}" 11 "${prs}"

  expected_list='- #11 and #10 both change:
  - `dot_vimrc`
  - `dot_zshrc`'
  [[ "$output" == *"${expected_list}"* ]]
  [ "$(grep -c 'dot_vimrc' <<<"$output")" -eq 1 ]
}

@test "a missing argument fails with usage" {
  run "${script}" 11

  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}
