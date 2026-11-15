#!/usr/bin/env bats
#
# Verifies the execution posture record: it exists in the chezmoi source, it
# renders to the home directory, it covers Claude Code, Codex, and OpenCode with
# every dimension, and the common instructions point to it.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/execution-posture.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source_dir="$(mktemp -d)"
  mkdir -p "${source_dir}/dot_agents" "${source_dir}/.chezmoitemplates/agents"
  cp "${repo_root}/dot_agents/execution-posture.md" "${source_dir}/dot_agents/"
  cp "${repo_root}/.chezmoitemplates/agents/common.md" "${source_dir}/.chezmoitemplates/agents/"
  validate="${repo_root}/.github/testdata/validate-execution-posture.sh"
}

teardown() {
  rm -rf "${source_dir}"
}

@test "the shipped record covers every tool and dimension and is referenced" {
  run bash "${validate}" "${source_dir}"
  [ "$status" -eq 0 ]
}

@test "a source without the record fails validation" {
  rm "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record that omits Claude Code fails validation" {
  sed -i.bak '/^## Claude Code$/s/.*/## Other tool/' "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record that omits Codex fails validation" {
  sed -i.bak '/^## Codex$/s/.*/## Other tool/' "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record that omits OpenCode fails validation" {
  sed -i.bak '/^## OpenCode$/s/.*/## Other tool/' "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a tool section missing the network dimension fails validation" {
  sed -i.bak '/^| Network |/d' "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record without the widening rule fails validation" {
  sed -i.bak '/^## Widening$/s/.*/## Other/' "${source_dir}/dot_agents/execution-posture.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "common instructions that do not point to the record fail validation" {
  sed -i.bak 's/execution-posture\.md/another-file.md/g' "${source_dir}/.chezmoitemplates/agents/common.md"
  run bash "${validate}" "${source_dir}"
  [ "$status" -ne 0 ]
}
