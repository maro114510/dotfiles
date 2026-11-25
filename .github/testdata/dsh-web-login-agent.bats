#!/usr/bin/env bats
#
# Verifies the LaunchAgent that keeps the Web GUI login gateway running: it starts
# the gateway under launchd, restarts it after an exit, and keeps its output in the
# owner-only state directory.
#
# Each test renders the template with chezmoi against a fixed home directory.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/dsh-web-login-agent.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  template="${repo_root}/Library/LaunchAgents/local.dsh-web-login.plist.tmpl"
  rendered="$(mktemp)"
}

teardown() {
  rm -f "${rendered}"
}

render() {
  "${chezmoi_bin}" execute-template --source "${repo_root}" \
    --config "${repo_root}/.github/testdata/chezmoi-full.toml" -f "${template}" >"${rendered}"
}

plist_value() {
  plutil -extract "$1" raw -o - "${rendered}"
}

@test "the agent is a valid property list" {
  run render
  [ "$status" -eq 0 ]
  plutil -lint "${rendered}"
}

@test "the agent has its own label, distinct from the Web GUI server" {
  render
  [ "$(plist_value Label)" = local.dsh-web-login ]
}

@test "the agent runs the gateway script from the home directory" {
  render
  [ "$(plist_value ProgramArguments.0)" = /usr/bin/env ]
  [ "$(plist_value ProgramArguments.1)" = "${HOME}/.local/bin/dsh-web-login" ]
}

@test "the agent starts at load and restarts after any exit" {
  render
  [ "$(plist_value RunAtLoad)" = true ]
  [ "$(plist_value KeepAlive)" = true ]
}

@test "a crash loop is slowed down" {
  render
  [ "$(plist_value ThrottleInterval)" -ge 10 ]
}

@test "output goes to the owner-only state directory, never to a shared path" {
  render
  [ "$(plist_value StandardOutPath)" = "${HOME}/.local/state/dsh-web/login.log" ]
  [ "$(plist_value StandardErrorPath)" = "${HOME}/.local/state/dsh-web/login.log" ]
}

@test "the agent resolves node through mise, not a hard-coded path" {
  render
  plist_value EnvironmentVariables.PATH | grep -q '/.local/share/mise/shims'
}
