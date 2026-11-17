#!/usr/bin/env bats
#
# Verifies how dotfiles shares the DSH configuration: ~/.dsh stays owner-only,
# the home patch carries the shared policy, the web manifest enforces the
# managed dependencies and bundles while keeping what DSH or the user added,
# the dsh wrapper runs the pinned release, and the install script runs only
# when its prerequisites exist.
#
# Each test applies the source to a throwaway home directory.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/dsh-config.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  home_dir="$(mktemp -d)"
  dsh_dir="${home_dir}/.dsh"
  manifest="${dsh_dir}/profiles/web/package.json"
  home_patch="${dsh_dir}/cordis.patch.yml"
  stub_dir="$(mktemp -d)"
  : > "${home_dir}/chezmoi.toml"
}

teardown() {
  rm -rf "${home_dir}" "${stub_dir}"
}

apply() {
  HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" apply "${dsh_dir}"
}

mode_of() {
  stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"
}

seed_manifest() {
  mkdir -p "${dsh_dir}/profiles/web"
  printf '%s\n' "$1" > "${manifest}"
}

# --- permissions ---

@test "~/.dsh is owner-only after apply" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(mode_of "${dsh_dir}")" = 700 ]
}

# --- home patch ---

@test "the home patch routes the model provider through an environment variable name" {
  run apply
  [ "$status" -eq 0 ]
  grep -q '^- id: llm-pi-ai$' "${home_patch}"
  grep -q 'apiKeyEnv: OPENCODE_GO_API_KEY' "${home_patch}"
}

@test "the home patch sets the permission presets and the default model" {
  run apply
  [ "$status" -eq 0 ]
  grep -q '^- id: permission$' "${home_patch}"
  grep -q 'defaultPreset: danger-full-access' "${home_patch}"
  grep -q '^- id: agent-default-model$' "${home_patch}"
  grep -q 'model: claude-sonnet-5-5' "${home_patch}"
}

@test "the home patch disables the official session log upload" {
  run apply
  [ "$status" -eq 0 ]
  grep -A4 '^- id: session-log-deepseek$' "${home_patch}" | grep -q 'enabled: false'
}

@test "the home patch keeps the Notion server defined and disabled" {
  run apply
  [ "$status" -eq 0 ]
  grep -A3 'id: mcp-notion$' "${home_patch}" | grep -q 'disabled: true'
}

@test "the home patch leaves Web UI preferences to the profile" {
  run apply
  [ "$status" -eq 0 ]
  [ -s "${home_patch}" ]
  ! grep -q -E 'welcomeNoticeVersion|transcriptView|preference:' "${home_patch}"
}

# --- web manifest ---

@test "a fresh home gets the managed dependencies and bundles" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(mode_of "${manifest}")" = 600 ]
  [ "$(jq -r '.dependencies["@deepseek-ai/dsh-subagent-codex"]' "${manifest}")" = 0.2.2-rc.1 ]
  [ "$(jq -r '.dependencies["dsh-ops"]' "${manifest}")" = '^0.5.4' ]
  [ "$(jq -r '.dsh.profile.bundles[0]' "${manifest}")" = '@deepseek-ai/dsh-base' ]
  [ "$(jq -r '.dsh.profile.bundles | index("dsh-context") != null' "${manifest}")" = true ]
}

@test "a local dependency and a local bundle survive an apply" {
  seed_manifest '{"name":"dsh-profile-web","dependencies":{"left-pad":"1.3.0"},"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","left-pad"]}}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dependencies["left-pad"]' "${manifest}")" = 1.3.0 ]
  [ "$(jq -r '.dsh.profile.bundles[-1]' "${manifest}")" = left-pad ]
  [ "$(jq -r '.dsh.profile.bundles | index("dsh-context") != null' "${manifest}")" = true ]
}

@test "a differing managed version is restored to the managed value" {
  seed_manifest '{"dependencies":{"dsh-ops":"^0.1.0"},"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base"]}}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dependencies["dsh-ops"]' "${manifest}")" = '^0.5.4' ]
}

@test "a managed bundle removed locally is restored without duplicating the others" {
  seed_manifest '{"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","@deepseek-ai/dsh-web-app"]}}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dsh.profile.bundles | map(select(. == "@deepseek-ai/dsh-base")) | length' "${manifest}")" = 1 ]
  [ "$(jq -r '.dsh.profile.bundles | index("dsh-ops") != null' "${manifest}")" = true ]
}

@test "a patch reload mode chosen locally survives an apply" {
  seed_manifest '{"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base"],"patchReload":"restart"}}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dsh.profile.patchReload' "${manifest}")" = restart ]
}

@test "a second apply leaves the manifest and the home patch unchanged" {
  run apply
  [ "$status" -eq 0 ]
  before="$(cat "${manifest}" "${home_patch}")"
  run apply
  [ "$status" -eq 0 ]
  [ "$(cat "${manifest}" "${home_patch}")" = "${before}" ]
  HOME="${home_dir}" run "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" verify "${dsh_dir}"
  [ "$status" -eq 0 ]
}

# --- wrapper ---

@test "the dsh wrapper runs the pinned release and passes every argument" {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*"\n' > "${stub_dir}/npx"
  chmod +x "${stub_dir}/npx"
  PATH="${stub_dir}:${PATH}" run bash "${repo_root}/dot_local/bin/executable_dsh" web --no-open
  [ "$status" -eq 0 ]
  [ "$output" = '--yes @deepseek-ai/dsh@0.2.2-rc.1 web --no-open' ]
}

# --- install script ---

install_script="run_after_dsh-profile-install.sh"

stub_install_env() {
  mkdir -p "${home_dir}/.local/bin" "${dsh_dir}/profiles/web"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/dsh.log"\n' "${stub_dir}" > "${home_dir}/.local/bin/dsh"
  chmod +x "${home_dir}/.local/bin/dsh"
  printf '#!/bin/sh\n' > "${stub_dir}/pnpm"
  chmod +x "${stub_dir}/pnpm"
  : > "${manifest}"
}

run_install() {
  HOME="${home_dir}" PATH="${stub_dir}:/usr/bin:/bin" run bash "${repo_root}/${install_script}"
}

@test "the install script installs the web profile when its prerequisites exist" {
  stub_install_env
  run_install
  [ "$status" -eq 0 ]
  [ "$(cat "${stub_dir}/dsh.log")" = 'plugin --profile web install' ]
}

@test "the install script skips with a message when pnpm is missing" {
  stub_install_env
  rm "${stub_dir}/pnpm"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *skipping* ]]
  [ ! -e "${stub_dir}/dsh.log" ]
}

@test "the install script skips with a message when the wrapper is missing" {
  stub_install_env
  rm "${home_dir}/.local/bin/dsh"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *skipping* ]]
}

@test "the install script skips with a message when the web manifest is missing" {
  stub_install_env
  rm "${manifest}"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *skipping* ]]
  [ ! -e "${stub_dir}/dsh.log" ]
}
