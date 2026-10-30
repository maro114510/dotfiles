#!/usr/bin/env bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source_dir="$(mktemp -d)"
  mkdir -p "${source_dir}/dot_claude" "${source_dir}/dot_codex" \
    "${source_dir}/dot_config/opencode" "${source_dir}/.chezmoitemplates/agents"
  cp "${repo_root}/.chezmoitemplates/agents/"* "${source_dir}/.chezmoitemplates/agents/"
  cp "${repo_root}/dot_claude/CLAUDE.md.tmpl" "${source_dir}/dot_claude/"
  cp "${repo_root}/dot_codex/AGENTS.md.tmpl" "${source_dir}/dot_codex/"
  cp "${repo_root}/dot_config/opencode/AGENTS.md.tmpl" "${source_dir}/dot_config/opencode/"
}

teardown() {
  rm -rf "${source_dir}"
}

@test "valid instruction templates render with the common body" {
  run bash "${repo_root}/.github/testdata/validate-instruction-templates.sh" "${source_dir}"
  [ "$status" -eq 0 ]
}

@test "a missing include target fails validation" {
  printf '{{ template "agents/missing.md" . }}\n' > "${source_dir}/dot_claude/CLAUDE.md.tmpl"
  run bash "${repo_root}/.github/testdata/validate-instruction-templates.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}

@test "a generated file without the common body fails validation" {
  printf '# Tool-specific content only\n' > "${source_dir}/dot_claude/CLAUDE.md.tmpl"
  run bash "${repo_root}/.github/testdata/validate-instruction-templates.sh" "${source_dir}"
  [ "$status" -ne 0 ]
}
