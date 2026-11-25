#!/usr/bin/env bats
#
# Verifies the Web GUI login gateway: a request that Tailscale Serve vouches for
# gets the current token URL as a redirect, and every other request gets nothing.
#
# Each test starts the gateway on an ephemeral loopback port with a throwaway
# state directory and configuration, so no network service or credential is used.
#
# Usage: bats .github/testdata/dsh-web-login.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  gateway="${repo_root}/dot_local/bin/executable_dsh-web-login"
  sandbox="$(mktemp -d)"
  state_dir="${sandbox}/state/dsh-web"
  mkdir -p "${state_dir}"
  url_file="${state_dir}/url"
  conf="${sandbox}/web-launch.conf"
  token_url='https://gui.example.test/?token=SECRET_TOKEN_1'
  printf '%s\n' "${token_url}" >"${url_file}"
  printf 'LOGIN_ALLOWED_USER=me@example.com\nLOGIN_PORT=0\n' >"${conf}"
  pid=""
  port=""
}

teardown() {
  [ -z "${pid}" ] || kill "${pid}" 2>/dev/null || true
  rm -rf "${sandbox}"
}

start_gateway() {
  XDG_STATE_HOME="${sandbox}/state" DSH_WEB_CONF="${conf}" node "${gateway}" >"${sandbox}/out" 2>&1 &
  pid=$!
  local waited=0
  while [ "${waited}" -lt 50 ]; do
    port="$(sed -n 's/^listening on 127\.0\.0\.1:\([0-9][0-9]*\)$/\1/p' "${sandbox}/out" | head -1)"
    [ -z "${port}" ] || return 0
    kill -0 "${pid}" 2>/dev/null || return 0
    sleep 0.1
    waited=$((waited + 1))
  done
}

# Prints the status code; headers and body land in the sandbox.
request() {
  curl -s -m 5 -o "${sandbox}/body" -D "${sandbox}/headers" -w '%{http_code}' "$@" || true
}

header() {
  sed -n "s/^$1: *//Ip" "${sandbox}/headers" | tr -d '\r' | head -1
}

# --- who is let in ---

@test "the allowed Tailscale login is redirected to the current token URL" {
  start_gateway
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 303 ]
  [ "$(header location)" = "${token_url}" ]
}

@test "the redirect is not cached and carries no referrer" {
  start_gateway
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 303 ]
  [ "$(header cache-control)" = no-store ]
  [ "$(header referrer-policy)" = no-referrer ]
}

@test "another Tailscale login is refused without the token" {
  start_gateway
  [ "$(request -H 'Tailscale-User-Login: other@example.com' "http://127.0.0.1:${port}/")" = 403 ]
  [ -z "$(header location)" ]
  ! grep -q SECRET_TOKEN "${sandbox}/body"
}

@test "a request without the Tailscale login header is refused" {
  start_gateway
  [ "$(request "http://127.0.0.1:${port}/")" = 403 ]
  [ -z "$(header location)" ]
}

@test "a login that only contains the allowed login is refused" {
  start_gateway
  [ "$(request -H 'Tailscale-User-Login: me@example.com.evil.test' "http://127.0.0.1:${port}/")" = 403 ]
  [ "$(request -H 'Tailscale-User-Login: xme@example.com' "http://127.0.0.1:${port}/")" = 403 ]
}

@test "any path with the allowed login redirects, and any other method is refused" {
  start_gateway
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/anything?x=1")" = 303 ]
  [ "$(request -X POST -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 405 ]
}

# --- which URL is served ---

@test "a new token URL written after the start is served on the next request" {
  start_gateway
  printf '%s\n' 'https://gui.example.test/?token=SECRET_TOKEN_2' >"${url_file}"
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 303 ]
  [ "$(header location)" = 'https://gui.example.test/?token=SECRET_TOKEN_2' ]
}

@test "a missing URL file is reported as unavailable, not as a redirect" {
  start_gateway
  rm -f "${url_file}"
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 503 ]
  [ -z "$(header location)" ]
}

@test "a URL file that is not an http or https URL is never used as a redirect" {
  start_gateway
  printf '%s\n' 'javascript:alert(1)' >"${url_file}"
  [ "$(request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/")" = 503 ]
  [ -z "$(header location)" ]
}

# --- startup and logs ---

@test "the gateway refuses to start without an allowed login" {
  printf 'LOGIN_PORT=0\n' >"${conf}"
  run env XDG_STATE_HOME="${sandbox}/state" DSH_WEB_CONF="${conf}" node "${gateway}"
  [ "$status" -ne 0 ]
  [[ "$output" == *LOGIN_ALLOWED_USER* ]]
}

@test "the gateway listens on loopback only" {
  start_gateway
  grep -q '^listening on 127\.0\.0\.1:[0-9]*$' "${sandbox}/out"
}

@test "the token never reaches the log, whoever asks" {
  start_gateway
  request -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:${port}/" >/dev/null
  request -H 'Tailscale-User-Login: other@example.com' "http://127.0.0.1:${port}/" >/dev/null
  [ -s "${sandbox}/out" ]
  ! grep -q SECRET_TOKEN "${sandbox}/out"
}
