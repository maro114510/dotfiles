#!/usr/bin/env bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source_dir="$(mktemp -d)"
  mkdir -p "${source_dir}/dot_config/agents" \
    "${source_dir}/.chezmoitemplates/agents"
  cp "${repo_root}/dot_config/agents/execution-risk-budget.md.tmpl" \
    "${source_dir}/dot_config/agents/"
  cp "${repo_root}/.chezmoitemplates/agents/common.md" \
    "${source_dir}/.chezmoitemplates/agents/"
  record="${source_dir}/dot_config/agents/execution-risk-budget.md.tmpl"
}

teardown() {
  rm -rf "${source_dir}"
}

drop_heading() {
  local file=$1 heading=$2 tmp
  tmp="$(mktemp)"
  grep -v -F -x -- "${heading}" "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

@test "the execution risk budget renders and covers every tool" {
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -eq 0 ]
}

@test "a missing execution risk budget fails validation" {
  rm "${record}"
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record without Codex fails validation" {
  drop_heading "${record}" "## Codex"
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record without Claude Code fails validation" {
  drop_heading "${record}" "## Claude Code"
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a record without OpenCode fails validation" {
  drop_heading "${record}" "## OpenCode"
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a common body without the record reference fails validation" {
  printf '# Common body\n\nNo reference here.\n' \
    > "${source_dir}/.chezmoitemplates/agents/common.md"
  run bash "${repo_root}/.github/testdata/validate-execution-risk-budget.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}
