#!/usr/bin/env bats
#
# Verifies that the Claude Code and Codex settings templates overlay only the
# shared core and keep everything a machine or the tool itself wrote, so
# `chezmoi apply` never reverts a per-machine choice.
#
# Each test renders a template against a throwaway home directory.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/agent-settings-core.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  home_dir="$(mktemp -d)"
  mkdir -p "${home_dir}/.claude" "${home_dir}/.codex"
  : > "${home_dir}/chezmoi.toml"
}

teardown() {
  rm -rf "${home_dir}"
}

# A failed [[ ]] before a test's last line does not fail the test under bash 3.2.
has() { [ -n "$(grep -F -- "$1" <<<"$output")" ]; }
lacks() { [ -z "$(grep -F -- "$1" <<<"$output")" ]; }

render() {
  HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" execute-template < "${repo_root}/${1}"
}

@test "claude keeps the machine's own keys and overlays only the core" {
  cat > "${home_dir}/.claude/settings.json" <<'EOF'
{"model":"opus","enabledPlugins":{"p@m":true},"hooks":{"SessionStart":[]},
 "permissions":{"allow":["Bash(ls:*)"],"defaultMode":"bypassPermissions","deny":["Bash(foo:*)"]}}
EOF
  run render dot_claude/settings.json.tmpl
  [ "$status" -eq 0 ]
  [ "$(jq -r .model <<<"$output")" = opus ]
  [ "$(jq -r '.enabledPlugins["p@m"]' <<<"$output")" = true ]
  [ "$(jq -c .hooks <<<"$output")" = '{"SessionStart":[]}' ]
  [ "$(jq -c .permissions.allow <<<"$output")" = '["Bash(ls:*)"]' ]
  [ "$(jq -r .permissions.defaultMode <<<"$output")" = bypassPermissions ]
  [ "$(jq '.permissions.deny | index("Read(~/.ssh/**/*)") != null' <<<"$output")" = true ]
  [ "$(jq -r .attribution.commit <<<"$output")" = "" ]
}

@test "claude drops permissions.read, which Claude Code does not read" {
  echo '{"permissions":{"read":{"deny":["**/.ssh/**"]}}}' > "${home_dir}/.claude/settings.json"
  run render dot_claude/settings.json.tmpl
  [ "$status" -eq 0 ]
  [ "$(jq -c '.permissions | has("read")' <<<"$output")" = false ]
}

@test "claude returns an already-applied file byte for byte" {
  render dot_claude/settings.json.tmpl > "${home_dir}/first.json"
  cp "${home_dir}/first.json" "${home_dir}/.claude/settings.json"
  run render dot_claude/settings.json.tmpl
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "${home_dir}/first.json")" ]
}

@test "claude on a new machine writes only the core" {
  run render dot_claude/settings.json.tmpl
  [ "$status" -eq 0 ]
  [ "$(jq -c 'keys' <<<"$output")" = '["attribution","cleanupPeriodDays","permissions","statusLine"]' ]
  [ "$(jq -c '.permissions | keys' <<<"$output")" = '["deny"]' ]
}

@test "codex keeps the machine's settings and refuses to trust the root or home" {
  cat > "${home_dir}/.codex/config.toml" <<EOF
model = "m1"
sandbox_mode = "workspace-write"

[projects."/"]
trust_level = "trusted"

[projects."${home_dir}"]
trust_level = "trusted"

[projects."${home_dir}/repo"]
trust_level = "trusted"
EOF
  run render dot_codex/private_config.toml.tmpl
  [ "$status" -eq 0 ]
  has 'model = "m1"'
  has 'sandbox_mode = "workspace-write"'
  has "[projects.\"${home_dir}/repo\"]"
  lacks '[projects."/"]'
  lacks "[projects.\"${home_dir}\"]"
}

@test "codex returns a file with nothing to remove byte for byte" {
  printf '# kept\nmodel = "m1"\n' > "${home_dir}/.codex/config.toml"
  run render dot_codex/private_config.toml.tmpl
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "${home_dir}/.codex/config.toml")" ]
}
