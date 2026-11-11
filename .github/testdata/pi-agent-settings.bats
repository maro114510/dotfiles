#!/usr/bin/env bats
#
# Verifies that the Pi settings merge applies the shared defaults and keeps
# everything Pi or the user wrote itself, so `chezmoi apply` never drops a
# package declaration, device ID, or a choice made through /settings.
# It also pins the footer extension: exactly one version-pinned pi-statusline
# entry, and no pi-starship, because both claim Pi's footer.
#
# Each test applies the source to a throwaway home directory.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/pi-agent-settings.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  home_dir="$(mktemp -d)"
  settings="${home_dir}/.pi/agent/settings.json"
  : > "${home_dir}/chezmoi.toml"
}

teardown() {
  rm -rf "${home_dir}"
}

apply() {
  HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" apply "${home_dir}/.pi"
}

seed() {
  mkdir -p "${home_dir}/.pi/agent"
  printf '%s\n' "$1" > "${settings}"
}

@test "a fresh home gets every shared default" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . "${settings}")" = '{"autocompleteMaxVisible":10,"defaultModel":"claude-sonnet-5-5","defaultProjectTrust":"ask","defaultProvider":"claude-code","defaultThinkingLevel":"medium","doubleEscapeAction":"tree","editorPaddingX":1,"enableInstallTelemetry":false,"enabledModels":["claude-code/*","opencode-go/*","local/*"],"outputPad":1,"packages":["npm:@narumitw/pi-statusline@0.51.0"],"quietStartup":"header","terminal":{"showTerminalProgress":true}}' ]
}

@test "a fresh home gets neither theme nor cacheWarming" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq 'has("theme") or has("cacheWarming")' "${settings}")" = false ]
}

@test "a fresh home gets no Pi-owned field" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq 'has("deviceId") or has("lastChangelogVersion")' "${settings}")" = false ]
}

@test "Pi-owned fields survive an apply" {
  seed '{"packages":["https://github.com/earendil-works/pi-claude-code"],"deviceId":"1986c36e","lastChangelogVersion":"1.5.0"}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["https://github.com/earendil-works/pi-claude-code","npm:@narumitw/pi-statusline@0.51.0"]' ]
  [ "$(jq -r .deviceId "${settings}")" = 1986c36e ]
  [ "$(jq -r .lastChangelogVersion "${settings}")" = 1.5.0 ]
}

@test "Pi-owned fields survive repeated applies" {
  seed '{"packages":["a","b"],"deviceId":"d1","lastChangelogVersion":"1.5.0"}'
  run apply
  [ "$status" -eq 0 ]
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["a","b","npm:@narumitw/pi-statusline@0.51.0"]' ]
  [ "$(jq -r .deviceId "${settings}")" = d1 ]
}

@test "the shared defaults replace a different value already in the target" {
  seed '{"defaultProvider":"anthropic","defaultModel":"claude-opus-4-8"}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r .defaultProvider "${settings}")" = claude-code ]
  [ "$(jq -r .defaultModel "${settings}")" = claude-sonnet-5-5 ]
}

@test "a setting outside the shared defaults survives an apply" {
  seed '{"theme":"light","terminal":{"showImages":false}}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -r .theme "${settings}")" = light ]
  [ "$(jq -r .terminal.showImages "${settings}")" = false ]
  [ "$(jq -r .terminal.showTerminalProgress "${settings}")" = true ]
}

@test "applying twice leaves the file unchanged" {
  seed '{"deviceId":"d1"}'
  run apply
  [ "$status" -eq 0 ]
  first="$(cat "${settings}")"
  run apply
  [ "$status" -eq 0 ]
  [ "$(cat "${settings}")" = "${first}" ]
}

@test "an existing file that is not valid JSON fails the apply and stays untouched" {
  seed '{"deviceId":'
  run apply
  [ "$status" -ne 0 ]
  [ -n "$(grep -F 'error calling fromJson' <<<"$output")" ]
  [ "$(cat "${settings}")" = '{"deviceId":' ]
}

@test "an unpinned or other pi-statusline entry is replaced by the pinned one" {
  seed '{"packages":["npm:@narumitw/pi-statusline","a","npm:@narumitw/pi-statusline@0.40.0"]}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["a","npm:@narumitw/pi-statusline@0.51.0"]' ]
}

@test "a pi-starship entry is removed, in string or object form" {
  seed '{"packages":["npm:@narumitw/pi-starship","a",{"source":"npm:@narumitw/pi-starship@0.67.1","skills":[]},{"source":"b"}]}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["a",{"source":"b"},"npm:@narumitw/pi-statusline@0.51.0"]' ]
}

@test "a pi-statusline entry in object form is replaced by the pinned one" {
  seed '{"packages":[{"source":"npm:@narumitw/pi-statusline"}]}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["npm:@narumitw/pi-statusline@0.51.0"]' ]
}

@test "a package whose name only starts with pi-statusline or pi-starship survives" {
  seed '{"packages":["npm:@narumitw/pi-statusline-extra","npm:@narumitw/pi-starship-extra"]}'
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c .packages "${settings}")" = '["npm:@narumitw/pi-statusline-extra","npm:@narumitw/pi-starship-extra","npm:@narumitw/pi-statusline@0.51.0"]' ]
}

@test "a fresh home gets the statusline segments of the Detailed information level" {
  run apply
  [ "$status" -eq 0 ]
  [ "$(jq -c . "${home_dir}/.pi/agent/pi-statusline.json")" = '{"segments":["provider","model","thinking","cwd","branch","tools","context","tokens","cache","cost","time"]}' ]
}

@test "the source holds only the settings merge, the statusline settings, the instruction template, and the go-router extension under dot_pi" {
  run git -C "${repo_root}" ls-files dot_pi
  [ "$status" -eq 0 ]
  [ "$output" = "dot_pi/agent/AGENTS.md.tmpl
dot_pi/agent/extensions/go-router.ts
dot_pi/agent/modify_settings.json
dot_pi/agent/pi-statusline.json" ]
}

@test "the source holds no Pi runtime data" {
  run git -C "${repo_root}" grep -l -E 'deviceId|lastChangelogVersion' -- dot_pi
  [ "$status" -ne 0 ]
}
