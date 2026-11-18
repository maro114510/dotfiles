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
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
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
  [ "$(jq -r '.dependencies | has("@deepseek-ai/dsh-subagent-codex")' "${manifest}")" = false ]
  [ "$(jq -r '.dsh.profile.bundles | index("@deepseek-ai/dsh-subagent-codex") == null' "${manifest}")" = true ]
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

@test "the subagent plugins left in a manifest are removed by an apply" {
  seed_manifest '{"dependencies":{"@deepseek-ai/dsh-subagent-codex":"0.2.2-rc.1","@deepseek-ai/dsh-subagent-claude-code":"0.2.2-rc.1","left-pad":"1.3.0"},"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","@deepseek-ai/dsh-subagent-codex","@deepseek-ai/dsh-subagent-claude-code","left-pad"]}}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dependencies | keys | map(select(startswith("@deepseek-ai/dsh-subagent-"))) | length' "${manifest}")" = 0 ]
  [ "$(jq -r '.dsh.profile.bundles | map(select(startswith("@deepseek-ai/dsh-subagent-"))) | length' "${manifest}")" = 0 ]
  [ "$(jq -r '.dependencies["left-pad"]' "${manifest}")" = 1.3.0 ]
  [ "$(jq -r '.dsh.profile.bundles[-1]' "${manifest}")" = left-pad ]
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

# --- wrapper ---

wrapper_env() {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/npx.log"\n' "${stub_dir}" > "${stub_dir}/npx"
  chmod +x "${stub_dir}/npx"
  cat > "${stub_dir}/releases.json" <<'JSON'
[{"tag_name":"dsh-v0.2.2-rc.2","draft":false,"published_at":"2026-11-12T02:16:12Z"},
 {"tag_name":"dsh-v0.2.2-rc.3","draft":false,"published_at":"2026-11-13T08:05:45Z"}]
JSON
  cat > "${stub_dir}/dist-tags.json" <<'JSON'
{"latest":"0.2.2-rc.1","next":"0.2.2-rc.3"}
JSON
  cat > "${stub_dir}/curl" <<'CURL'
#!/bin/sh
case "$*" in
  *api.github.com*) [ -f "${STUB_DIR}/github-fails" ] && exit 22; cat "${STUB_DIR}/releases.json" ;;
  *registry.npmjs.org*) cat "${STUB_DIR}/dist-tags.json" ;;
  *) exit 22 ;;
esac
CURL
  chmod +x "${stub_dir}/curl"
  export STUB_DIR="${stub_dir}"
  export HOME="${home_dir}"
  export XDG_STATE_HOME="${home_dir}/.local/state"
}

run_wrapper() {
  PATH="${stub_dir}:/opt/homebrew/bin:/usr/bin:/bin" run bash "${repo_root}/dot_local/bin/executable_dsh" "$@"
}

@test "the dsh wrapper runs the newest published release and passes every argument" {
  wrapper_env
  run_wrapper web --no-open
  [ "$status" -eq 0 ]
  [ "$(cat "${stub_dir}/npx.log")" = '--yes @deepseek-ai/dsh@0.2.2-rc.3 web --no-open' ]
}

@test "the dsh wrapper reuses a fresh resolution instead of asking again" {
  wrapper_env
  run_wrapper --resolved-version
  run_wrapper --resolved-version
  [ "$status" -eq 0 ]
  [ "$output" = '0.2.2-rc.3' ]
  [ ! -e "${stub_dir}/npx.log" ]
}

@test "the dsh wrapper honors DSH_VERSION" {
  wrapper_env
  DSH_VERSION=0.2.2-rc.9 run_wrapper web
  [ "$status" -eq 0 ]
  [ "$(cat "${stub_dir}/npx.log")" = '--yes @deepseek-ai/dsh@0.2.2-rc.9 web' ]
}

@test "the dsh wrapper falls back to npm when GitHub is unreachable" {
  wrapper_env
  : > "${stub_dir}/github-fails"
  run_wrapper --resolved-version
  [ "$status" -eq 0 ]
  [ "$output" = '0.2.2-rc.3' ]
}

@test "a release marked failing is replaced by the last good one" {
  wrapper_env
  mkdir -p "${home_dir}/.local/state/dsh/failing"
  printf '%s\n' "$(date +%s)" > "${home_dir}/.local/state/dsh/failing/0.2.2-rc.3"
  printf '%s\n' 0.2.2-rc.1 > "${home_dir}/.local/state/dsh/last-good"
  run_wrapper --resolved-version
  [ "$status" -eq 0 ]
  [[ "${output}" == *0.2.2-rc.1* ]]
}

@test "the wrapper no longer pins a release" {
  ! grep -q '@deepseek-ai/dsh@0\.' "${repo_root}/dot_local/bin/executable_dsh"
}

# --- LaunchAgent and supervisor ---

apply_agent() {
  mkdir -p "${home_dir}/Library/LaunchAgents"
  HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" apply "${home_dir}/Library/LaunchAgents/local.dsh-web.plist"
}

supervisor_env() {
  mkdir -p "${home_dir}/.local/bin" "${dsh_dir}" "${home_dir}/.local/state/dsh-web"
  printf '#!/bin/sh\n[ "${1:-}" = "--resolved-version" ] && { echo 0.2.2-rc.3; exit 0; }\nexit 0\n' \
    > "${home_dir}/.local/bin/dsh"
  chmod +x "${home_dir}/.local/bin/dsh"
  printf 'PORT=3080\nPUBLIC_URL=https://example.invalid/\nTRUSTED_HOST=example.invalid\n' \
    > "${dsh_dir}/web-launch.conf"
}

run_supervisor() {
  HOME="${home_dir}" DSH_HOME="${dsh_dir}" PATH="${stub_dir}:/opt/homebrew/bin:/usr/bin:/bin" \
    run bash "${repo_root}/dot_local/bin/executable_dsh-web-supervisor" "$@"
}

@test "a LaunchAgent keeps the Web GUI on the newest release" {
  run apply_agent
  [ "$status" -eq 0 ]
  agent="${home_dir}/Library/LaunchAgents/local.dsh-web.plist"
  [ -f "${agent}" ]
  grep -q '<string>local.dsh-web</string>' "${agent}"
  grep -q 'dsh-web-supervisor' "${agent}"
  grep -A1 '<key>KeepAlive</key>' "${agent}" | grep -q '<true/>'
  grep -A1 '<key>RunAtLoad</key>' "${agent}" | grep -q '<true/>'
}

@test "the supervisor reports the resolved and last good releases" {
  supervisor_env
  run_supervisor check
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'resolved=0.2.2-rc.3' ]
  [ "${lines[1]}" = 'last-good=none' ]
}

@test "the supervisor reads the last good release the wrapper keeps" {
  supervisor_env
  mkdir -p "${home_dir}/.local/state/dsh"
  printf '0.2.2-rc.1\n' > "${home_dir}/.local/state/dsh/last-good"
  run_supervisor check
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = 'last-good=0.2.2-rc.1' ]
}

@test "the supervisor refuses to start without its machine-local config" {
  supervisor_env
  rm "${dsh_dir}/web-launch.conf"
  run_supervisor status
  [ "$status" -ne 0 ]
  [[ "$output" == *web-launch.conf* ]]
}

# --- install script ---

install_script="run_after_dsh-profile-install.sh"

stub_install_env() {
  mkdir -p "${home_dir}/.local/bin" "${dsh_dir}/profiles/web"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/dsh.log"\n' "${stub_dir}" > "${home_dir}/.local/bin/dsh"
  chmod +x "${home_dir}/.local/bin/dsh"
  printf '#!/bin/sh\n' > "${stub_dir}/pnpm"
  printf '#!/bin/sh\n' > "${stub_dir}/npx"
  chmod +x "${stub_dir}/pnpm" "${stub_dir}/npx"
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

@test "the install script skips with a message when npx is missing" {
  stub_install_env
  rm "${stub_dir}/npx"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *skipping* ]]
  [ ! -e "${stub_dir}/dsh.log" ]
}

@test "the install script reports a failed install and still succeeds" {
  stub_install_env
  printf '#!/bin/sh\nexit 1\n' > "${home_dir}/.local/bin/dsh"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *failed* ]]
}


