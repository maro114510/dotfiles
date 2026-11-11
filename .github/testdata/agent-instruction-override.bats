#!/usr/bin/env bats
#
# Verifies that rendering a managed instruction file fails when a stray
# AGENTS.override.md exists in a tool's home directory, because that file
# replaces the managed instructions instead of adding to them.
#
# Each test renders the templates against a throwaway home directory.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/agent-instruction-override.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  home_dir="$(mktemp -d)"
  mkdir -p "${home_dir}/.codex" "${home_dir}/.claude" "${home_dir}/.config/opencode"
  : > "${home_dir}/chezmoi.toml"
}

teardown() {
  rm -rf "${home_dir}"
}

render() {
  HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" execute-template < "${repo_root}/${1}"
}

# Fails the test unless every managed instruction file refuses to render and names the override.
every_instruction_file_fails_naming() {
  local template
  for template in \
    dot_claude/CLAUDE.md.tmpl \
    dot_codex/AGENTS.md.tmpl \
    dot_config/opencode/AGENTS.md.tmpl \
    dot_pi/agent/AGENTS.md.tmpl; do
    run render "${template}"
    [ "$status" -ne 0 ] || { echo "${template} rendered"; return 1; }
    [ -n "$(grep -F -- "$1" <<<"$output")" ] || { echo "${template}: ${output}"; return 1; }
  done
}

@test "an override in ~/.codex fails every instruction file and names it" {
  : > "${home_dir}/.codex/AGENTS.override.md"
  every_instruction_file_fails_naming "${home_dir}/.codex/AGENTS.override.md"
}

@test "an override in ~/.claude fails every instruction file and names it" {
  : > "${home_dir}/.claude/AGENTS.override.md"
  every_instruction_file_fails_naming "${home_dir}/.claude/AGENTS.override.md"
}

@test "an override in ~/.config/opencode fails every instruction file and names it" {
  : > "${home_dir}/.config/opencode/AGENTS.override.md"
  every_instruction_file_fails_naming "${home_dir}/.config/opencode/AGENTS.override.md"
}

@test "without an override the codex instruction file renders" {
  run render dot_codex/AGENTS.md.tmpl
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
