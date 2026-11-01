#!/usr/bin/env bats
#
# Verifies that chezmoi manages the OpenCode orchestration tooling: a fresh
# HOME gets every skill and agent definition, the applied oe helper runs, and
# a second apply has nothing left to change.
#
# Each test applies a throwaway chezmoi source holding only dot_config/opencode
# to a throwaway HOME, so the real $HOME and ~/.config/opencode are never
# touched.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/opencode-skills.bats
# Set CHEZMOI to the chezmoi binary when it is not on PATH.

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  managed_skills=(orchestrate-epic pr-owner pr-verify create-pr implement commit)

  sandbox="$(mktemp -d)"
  home_dir="${sandbox}/home"
  source_dir="${sandbox}/source"
  mkdir -p "${home_dir}" "${source_dir}/dot_config/opencode"

  # Copy only the files under test so that no run_ script executes here.
  if [ -d "${repo_root}/dot_config/opencode/skills" ]; then
    cp -R "${repo_root}/dot_config/opencode/skills" "${source_dir}/dot_config/opencode/"
  fi
  if [ -d "${repo_root}/dot_config/opencode/agents" ]; then
    cp -R "${repo_root}/dot_config/opencode/agents" "${source_dir}/dot_config/opencode/"
  fi

  : > "${sandbox}/chezmoi.toml"
  HOME="${home_dir}" "${chezmoi_bin}" apply \
    --config "${sandbox}/chezmoi.toml" \
    --source "${source_dir}" \
    --destination "${home_dir}"
}

teardown() {
  rm -rf "${sandbox}"
}

@test "the repository tracks each orchestration skill and its agent definition" {
  for skill in "${managed_skills[@]}"; do
    [ -f "${repo_root}/dot_config/opencode/skills/${skill}/SKILL.md" ]
  done

  [ -f "${repo_root}/dot_config/opencode/agents/pr-owner.md" ]
  [ -f "${repo_root}/dot_config/opencode/agents/pr-verify.md" ]
}

@test "chezmoi apply installs an entry file for every tracked skill" {
  skills_root="${home_dir}/.config/opencode/skills"

  [ -d "${skills_root}" ]
  for skill_dir in "${repo_root}"/dot_config/opencode/skills/*/; do
    skill="$(basename "${skill_dir}")"
    [ -f "${skills_root}/${skill}/SKILL.md" ]
  done
}

@test "chezmoi apply installs both agent definitions" {
  agents_root="${home_dir}/.config/opencode/agents"

  [ -f "${agents_root}/pr-owner.md" ]
  [ -f "${agents_root}/pr-verify.md" ]
}

@test "the applied oe helper is executable and prints its usage" {
  oe="${home_dir}/.config/opencode/skills/orchestrate-epic/scripts/oe"

  [ -x "${oe}" ]
  run "${oe}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: oe ready"* ]]
}

@test "chezmoi apply keeps every managed executable executable" {
  managed_executables="$(find "${repo_root}/dot_config/opencode/skills" -name 'executable_*' -type f)"

  [ -n "${managed_executables}" ]
  while IFS= read -r source_file; do
    relative="${source_file#"${repo_root}"/dot_config/opencode/}"
    name="$(basename "${source_file}")"
    applied="${home_dir}/.config/opencode/${relative%/*}/${name#executable_}"
    [ -x "${applied}" ]
  done <<< "${managed_executables}"
}

@test "chezmoi diff is empty after chezmoi apply" {
  # Prove the apply happened before trusting an empty diff.
  [ -f "${home_dir}/.config/opencode/skills/orchestrate-epic/SKILL.md" ]

  run env HOME="${home_dir}" "${chezmoi_bin}" diff \
    --config "${sandbox}/chezmoi.toml" \
    --source "${source_dir}" \
    --destination "${home_dir}"
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}
