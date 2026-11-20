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

@test "the home patch caps automatic goal rounds" {
  run apply
  [ "$status" -eq 0 ]
  grep -A4 '^- id: goal$' "${home_patch}" | grep -q 'defaultMaxGoalRounds: 8'
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

@test "the home patch keeps the Claude prompt cache for one hour and restates the plugin's mount" {
  run apply
  [ "$status" -eq 0 ]
  grep -A4 '^- id: llm-subscriptions$' "${home_patch}" | grep -q 'claudePromptCacheTtl: 1h'
  grep -A2 '^- id: llm-subscriptions$' "${home_patch}" | grep -q 'name: dsh-plugin-subscriptions'
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

# Stubs every command run and status reach outside the sandbox: the server
# answers health checks, nothing listens on the port, and launchctl only logs.
supervisor_run_env() {
  supervisor_env
  cat > "${home_dir}/.local/bin/dsh" <<'SH'
#!/bin/sh
if [ "${1:-}" = "--resolved-version" ]; then echo "${DSH_VERSION:-0.2.2-rc.3}"; exit 0; fi
printf '%s|%s\n' "${DSH_VERSION:-}" "$*" >> "${STUB_DIR}/dsh.log"
SH
  chmod +x "${home_dir}/.local/bin/dsh"
  printf '#!/bin/sh\nprintf 200\n' > "${stub_dir}/curl"
  printf '#!/bin/sh\nexit 1\n' > "${stub_dir}/lsof"
  printf '#!/bin/sh\n' > "${stub_dir}/osascript"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/launchctl.log"\n' "${stub_dir}" > "${stub_dir}/launchctl"
  chmod +x "${stub_dir}/curl" "${stub_dir}/lsof" "${stub_dir}/osascript" "${stub_dir}/launchctl"
  export STUB_DIR="${stub_dir}"
}

@test "the supervisor reports its status without the machine-local config" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  run_supervisor status
  [ "$status" -eq 0 ]
  [[ "$output" == *"listener: none"* ]]
}

@test "the supervisor starts a local-only server without the machine-local config" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  run_supervisor run
  [ "$status" -eq 0 ]
  [ "$(cut -d'|' -f2 "${stub_dir}/dsh.log")" = 'web --no-open' ]
}

@test "the supervisor starts a local-only server when the config names no public URL" {
  supervisor_run_env
  printf 'PORT=3080\n' > "${dsh_dir}/web-launch.conf"
  run_supervisor run
  [ "$status" -eq 0 ]
  [ "$(cut -d'|' -f2 "${stub_dir}/dsh.log")" = 'web --no-open' ]
}

@test "stopping the supervisor passes the stop request to the server" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  cat > "${home_dir}/.local/bin/dsh" <<'SH'
#!/bin/bash
if [ "${1:-}" = "--resolved-version" ]; then echo 0.2.2-rc.3; exit 0; fi
trap 'echo drained >> "${STUB_DIR}/server.log"; exit 0' TERM
echo started >> "${STUB_DIR}/server.log"
while :; do sleep 0.1; done
SH
  HOME="${home_dir}" DSH_HOME="${dsh_dir}" PATH="${stub_dir}:/opt/homebrew/bin:/usr/bin:/bin" \
    bash "${repo_root}/dot_local/bin/executable_dsh-web-supervisor" run 3>&- &
  supervisor_pid=$!
  for _ in $(seq 50); do grep -q started "${stub_dir}/server.log" 2>/dev/null && break; sleep 0.1; done
  sleep 0.5
  kill -TERM "${supervisor_pid}"
  wait "${supervisor_pid}" || true
  for _ in $(seq 30); do grep -q drained "${stub_dir}/server.log" && break; sleep 0.1; done
  pkill -f "${home_dir}/.local/bin/dsh" || true
  grep -q drained "${stub_dir}/server.log"
}

@test "the supervisor keeps its state directory and logs owner-only" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  state="${home_dir}/.local/state/dsh-web"
  chmod 755 "${state}"
  : > "${state}/server.log"
  chmod 644 "${state}/server.log"
  run_supervisor run
  [ "$status" -eq 0 ]
  [ "$(mode_of "${state}")" = 700 ]
  [ "$(mode_of "${state}/server.log")" = 600 ]
  [ "$(mode_of "${state}/launchd.log")" = 600 ]
}

@test "the state script creates the supervisor state directory owner-only" {
  HOME="${home_dir}" run bash "${repo_root}/run_after_dsh-web-supervisor-state.sh"
  [ "$status" -eq 0 ]
  [ "$(mode_of "${home_dir}/.local/state/dsh-web")" = 700 ]
}

@test "the supervisor records the status a server exits with" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '#!/bin/sh\n[ "${1:-}" = "--resolved-version" ] && { echo 0.2.2-rc.3; exit 0; }\nexit 3\n' \
    > "${home_dir}/.local/bin/dsh"
  run_supervisor run
  [ "$status" -eq 3 ]
  grep -q 'dsh 0.2.2-rc.3 exited with status 3$' "${home_dir}/.local/state/dsh-web/launchd.log"
}

@test "the supervisor records the signal that ended a server" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '#!/bin/sh\n[ "${1:-}" = "--resolved-version" ] && { echo 0.2.2-rc.3; exit 0; }\nkill -KILL $$\n' \
    > "${home_dir}/.local/bin/dsh"
  run_supervisor run
  [ "$status" -eq 137 ]
  grep -q 'dsh 0.2.2-rc.3 exited with status 137 (signal KILL)$' "${home_dir}/.local/state/dsh-web/launchd.log"
}

@test "the supervisor records a stop it passed to the server" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  cat > "${home_dir}/.local/bin/dsh" <<'SH'
#!/bin/bash
if [ "${1:-}" = "--resolved-version" ]; then echo 0.2.2-rc.3; exit 0; fi
trap 'echo drained >> "${STUB_DIR}/server.log"; exit 0' TERM
echo started >> "${STUB_DIR}/server.log"
while :; do sleep 0.1; done
SH
  HOME="${home_dir}" DSH_HOME="${dsh_dir}" PATH="${stub_dir}:/opt/homebrew/bin:/usr/bin:/bin" \
    bash "${repo_root}/dot_local/bin/executable_dsh-web-supervisor" run 3>&- 2>/dev/null &
  supervisor_pid=$!
  for _ in $(seq 50); do grep -q started "${stub_dir}/server.log" 2>/dev/null && break; sleep 0.1; done
  sleep 0.5
  kill -TERM "${supervisor_pid}"
  wait "${supervisor_pid}" || true
  pkill -f "${home_dir}/.local/bin/dsh" || true
  grep -q 'stopped on request; dsh 0.2.2-rc.3 exited with status 0$' "${home_dir}/.local/state/dsh-web/launchd.log"
}

kept_version_file() {
  printf '%s' "${home_dir}/.local/state/dsh-web/version"
}

@test "a first start records the release it resolved" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  run_supervisor run
  [ "$status" -eq 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.3 ]
  [ "$(cat "${stub_dir}/dsh.log")" = '0.2.2-rc.3|web --no-open' ]
}

@test "a restart keeps the recorded release even when a newer one is published" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '0.2.2-rc.1\n' > "$(kept_version_file)"
  run_supervisor run
  [ "$status" -eq 0 ]
  [ "$(cat "${stub_dir}/dsh.log")" = '0.2.2-rc.1|web --no-open' ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.1 ]
}

@test "a recorded release that fails its health check is replaced by the last good one" {
  supervisor_run_env
  printf '#!/bin/sh\nprintf 000\n' > "${stub_dir}/curl"
  printf '0.2.2-rc.3\n' > "$(kept_version_file)"
  mkdir -p "${home_dir}/.local/state/dsh"
  printf '0.2.2-rc.1\n' > "${home_dir}/.local/state/dsh/last-good"
  DSH_WEB_HEALTH_SECONDS=0 run_supervisor run
  [ "$status" -ne 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.1 ]
}

@test "a first start that fails its health check without a last good release records nothing" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '#!/bin/sh\nprintf 000\n' > "${stub_dir}/curl"
  DSH_WEB_HEALTH_SECONDS=0 run_supervisor run
  [ "$status" -ne 0 ]
  [ ! -e "$(kept_version_file)" ]
}

@test "a failed start of the last good release keeps it recorded" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '#!/bin/sh\nprintf 000\n' > "${stub_dir}/curl"
  printf '0.2.2-rc.1\n' > "$(kept_version_file)"
  mkdir -p "${home_dir}/.local/state/dsh"
  printf '0.2.2-rc.1\n' > "${home_dir}/.local/state/dsh/last-good"
  DSH_WEB_HEALTH_SECONDS=0 run_supervisor run
  [ "$status" -ne 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.1 ]
}

@test "takeover fails when the server came back on another release than it recorded" {
  supervisor_run_env
  # launchd restarted on the last good release after the newest one failed.
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/launchctl.log"\nprintf "0.2.2-rc.1\\n" > "%s"\n' \
    "${stub_dir}" "$(kept_version_file)" > "${stub_dir}/launchctl"
  run_supervisor takeover
  [ "$status" -ne 0 ]
  [[ "$output" == *0.2.2-rc.1* ]]
}

@test "a failed start leaves a release that takeover recorded meanwhile" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '0.2.2-rc.3\n' > "$(kept_version_file)"
  mkdir -p "${home_dir}/.local/state/dsh"
  printf '0.2.2-rc.1\n' > "${home_dir}/.local/state/dsh/last-good"
  # takeover records 0.2.2-rc.5 while this start is still waiting for its health check.
  printf '#!/bin/sh\nprintf "0.2.2-rc.5\\n" > "%s"\nprintf 000\n' "$(kept_version_file)" > "${stub_dir}/curl"
  DSH_WEB_HEALTH_SECONDS=0 run_supervisor run
  [ "$status" -ne 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.5 ]
}

@test "a failed first start leaves a release that takeover recorded meanwhile" {
  supervisor_run_env
  rm "${dsh_dir}/web-launch.conf"
  printf '0.2.2-rc.3\n' > "$(kept_version_file)"
  printf '#!/bin/sh\nprintf "0.2.2-rc.5\\n" > "%s"\nprintf 000\n' "$(kept_version_file)" > "${stub_dir}/curl"
  DSH_WEB_HEALTH_SECONDS=0 run_supervisor run
  [ "$status" -ne 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.5 ]
}

@test "takeover fails when the recovery wait finds the last good release running" {
  supervisor_run_env
  # The first health check fails; launchd then falls back and the second one passes.
  printf '#!/bin/sh\nif [ -e "%s/checked" ]; then printf 200; else : > "%s/checked"; printf 000; fi\n' \
    "${stub_dir}" "${stub_dir}" > "${stub_dir}/curl"
  printf '#!/bin/sh\n[ -e "%s/checked" ] && printf "0.2.2-rc.1\\n" > "%s"\nexit 0\n' \
    "${stub_dir}" "$(kept_version_file)" > "${stub_dir}/launchctl"
  DSH_WEB_TAKEOVER_SECONDS=0 run_supervisor takeover
  [ "$status" -ne 0 ]
  [[ "$output" == *0.2.2-rc.1* ]]
}

@test "takeover refuses a requested release the wrapper would replace" {
  supervisor_run_env
  printf '0.2.2-rc.3\n' > "$(kept_version_file)"
  # The wrapper answers the last good release because the requested one failed recently.
  printf '#!/bin/sh\n[ "${1:-}" = "--resolved-version" ] && { echo 0.2.2-rc.1; exit 0; }\nexit 0\n' \
    > "${home_dir}/.local/bin/dsh"
  DSH_VERSION=0.2.2-rc.5 run_supervisor takeover
  [ "$status" -ne 0 ]
  [[ "$output" == *0.2.2-rc.5* ]]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.3 ]
  [ ! -e "${stub_dir}/launchctl.log" ]
}

@test "takeover moves the recorded release to the newest one and restarts the agent" {
  supervisor_run_env
  printf '0.2.2-rc.1\n' > "$(kept_version_file)"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.3 ]
  grep -q '^kickstart -k gui/' "${stub_dir}/launchctl.log"
}

@test "takeover records the release DSH_VERSION names" {
  supervisor_run_env
  DSH_VERSION=0.2.2-rc.5 run_supervisor takeover
  [ "$status" -eq 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.5 ]
}

# A takeover run that sees how dsh reports an incompatible plugin: the stubbed
# server appends the lines when launchd starts it, and the release dry run
# prints its own to stderr.
incompatible_bundle_line='dsh: skipping profile bundle "dsh-ops": Error: Plugin dsh-ops@0.5.5 is incompatible with dsh 0.2.2-rc.3: requirements {"engines.dsh":">=0.2.2-rc.1 <0.2.2-rc.3"}. Running it may cause crashes or data loss.'
incompatible_row_line='dsh: disabling profile plugin row "subagent-model-selection-settings": Plugin @deepseek-ai/dsh-tool-subagent@0.2.2-rc.1 is incompatible with dsh 0.2.2-rc.3: requirements {"@deepseek-ai/dsh-agent":"0.2.2-rc.1"}. Running it may cause crashes or data loss.'

server_log() {
  printf '%s' "${home_dir}/.local/state/dsh-web/server.log"
}

# launchctl stub that makes the restarted server write the given lines.
launchctl_writes_to_server_log() {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/launchctl.log"\n' "${stub_dir}" > "${stub_dir}/launchctl"
  for line in "$@"; do
    printf 'printf "%%s\\n" '"'%s'"' >> "%s"\n' "${line}" "$(server_log)" >> "${stub_dir}/launchctl"
  done
  chmod +x "${stub_dir}/launchctl"
}

# dsh stub whose release dry run prints the given lines to stderr.
dsh_dry_run_prints() {
  {
    printf '#!/bin/sh\n[ "${1:-}" = "--resolved-version" ] && { echo 0.2.2-rc.3; exit 0; }\n'
    printf 'case "$*" in *--dump-config*)\n'
    for line in "$@"; do
      printf "  printf '%%s\\\\n' '%s' >&2\\n" "${line}"
    done
    printf '  printf "%%s\\\\n" "${DSH_VERSION:-}" > "${STUB_DIR}/dry-run-version"\n  exit "${DRY_RUN_STATUS:-0}" ;;\nesac\nexit 0\n'
  } > "${home_dir}/.local/bin/dsh"
  chmod +x "${home_dir}/.local/bin/dsh"
}

@test "takeover names the bundle and the range dsh skipped after it" {
  supervisor_run_env
  launchctl_writes_to_server_log "${incompatible_bundle_line}"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" == *'dsh-ops'* ]]
  [[ "$output" == *'"engines.dsh":">=0.2.2-rc.1 <0.2.2-rc.3"'* ]]
}

@test "takeover names the plugin row and the range dsh disabled after it" {
  supervisor_run_env
  launchctl_writes_to_server_log "${incompatible_row_line}"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" == *'subagent-model-selection-settings'* ]]
  [[ "$output" == *'dsh-tool-subagent@0.2.2-rc.1'* ]]
  [[ "$output" == *'"@deepseek-ai/dsh-agent":"0.2.2-rc.1"'* ]]
}

@test "takeover ignores incompatibility lines the server logged before it" {
  supervisor_run_env
  printf '%s\n' "${incompatible_bundle_line}" > "$(server_log)"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" != *'dsh-ops'* ]]
}

@test "takeover prints nothing about plugins when the server log has no incompatibility" {
  supervisor_run_env
  printf 'dsh: listening\n' > "$(server_log)"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" != *'skipping profile bundle'* ]]
  [[ "$output" != *'disabling profile plugin row'* ]]
  [[ "$output" != *'incompatib'* ]]
}

@test "takeover warns before recording a release an installed plugin excludes, and completes" {
  supervisor_run_env
  dsh_dry_run_prints "${incompatible_bundle_line}"
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [ "$(cat "${stub_dir}/dry-run-version")" = 0.2.2-rc.3 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.3 ]
  [[ "$output" == *'dsh-ops'* ]]
  warned_at="${output%%dsh-ops*}"
  recorded_at="${output%%recorded dsh*}"
  [ "${#warned_at}" -lt "${#recorded_at}" ]
}

@test "takeover reports no file error when the server has not logged yet" {
  supervisor_run_env
  [ ! -e "$(server_log)" ]
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" != *'No such file'* ]]
}

@test "takeover after a rollback does not attribute the logged lines to the release that failed" {
  supervisor_run_env
  printf '#!/bin/sh\nif [ -e "%s/checked" ]; then printf 200; else : > "%s/checked"; printf 000; fi\n' \
    "${stub_dir}" "${stub_dir}" > "${stub_dir}/curl"
  printf '#!/bin/sh\n[ -e "%s/checked" ] && printf "%%s\\n" '"'%s'"' >> "%s"\nexit 0\n' \
    "${stub_dir}" "${incompatible_bundle_line}" "$(server_log)" > "${stub_dir}/launchctl"
  chmod +x "${stub_dir}/launchctl"
  DSH_WEB_TAKEOVER_SECONDS=0 run_supervisor takeover
  [[ "$output" == *'dsh-ops'* ]]
  [[ "$output" != *'dsh 0.2.2-rc.3 disabled'* ]]
}

@test "takeover completes when the release dry run fails" {
  supervisor_run_env
  dsh_dry_run_prints
  DRY_RUN_STATUS=1 run_supervisor takeover
  [ "$status" -eq 0 ]
  [ "$(cat "$(kept_version_file)")" = 0.2.2-rc.3 ]
}

@test "takeover prints no warning when the release dry run reports no incompatibility" {
  supervisor_run_env
  dsh_dry_run_prints
  run_supervisor takeover
  [ "$status" -eq 0 ]
  [[ "$output" != *'incompatib'* ]]
  [[ "$output" != *'warning'* ]]
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


