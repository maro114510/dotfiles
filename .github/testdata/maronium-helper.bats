#!/usr/bin/env bats
#
# Verifies that maronium-helper hands an agent a GitHub App installation token
# for one repository, through a background process that holds the App key.
#
# Every test runs in a sandbox HOME against a fake GitHub API that records each
# request and a fake 1Password that counts each key read, so no credential and
# no network leaves the machine.
#
# Usage: bats .github/testdata/maronium-helper.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  helper="${repo_root}/dot_local/bin/executable_maronium-helper"
  sandbox="$(mktemp -d /tmp/maronium-helper.XXXXXX)"
  export helper
  export HOME="${sandbox}/home"
  mkdir -p "${HOME}/.config/maronium" "${sandbox}/bin"

  # The uncommitted local file: the App and installation to act as, and the
  # 1Password reference of the key.
  cat >"${HOME}/.config/maronium/helper.json" <<EOF
{"appId":12345,"installationId":67890,"keyRef":"op://test/maronium/private key"}
EOF
  chmod 600 "${HOME}/.config/maronium/helper.json"

  # A fake 1Password: prints a generated App key and counts each read.
  openssl genrsa -out "${sandbox}/app-key.pem" 2048 2>/dev/null
  cat >"${sandbox}/bin/op" <<EOF
#!/bin/bash
printf '%s\n' "\${2:-}" >>"${sandbox}/op-reads"
cat "${sandbox}/app-key.pem"
EOF
  chmod +x "${sandbox}/bin/op"
  export PATH="${sandbox}/bin:${PATH}"

  # A fake GitHub API. It answers for the installation 67890 of the account acme,
  # publishes ghs_test_<n> tokens, gives the repository "short" five minutes, and
  # treats the repository "missing" as outside the installation.
  cat >"${sandbox}/api.js" <<'EOF'
const http = require('node:http')
const fs = require('node:fs')
const [portFile, logFile] = process.argv.slice(2)
let minted = 0
const send = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json' })
  res.end(JSON.stringify(body))
}
http
  .createServer((req, res) => {
    let raw = ''
    req.on('data', (chunk) => (raw += chunk))
    req.on('end', () => {
      const body = raw ? JSON.parse(raw) : null
      fs.appendFileSync(logFile, `${JSON.stringify({ method: req.method, url: req.url, body })}\n`)
      if (req.method === 'GET' && req.url === '/app/installations/67890') {
        return send(res, 200, { id: 67890, account: { login: 'acme' } })
      }
      if (req.method === 'POST' && req.url === '/app/installations/67890/access_tokens') {
        const name = body.repositories[0]
        if (name === 'missing') return send(res, 422, { message: 'Repository not accessible' })
        minted += 1
        const minutes = name === 'short' ? 5 : 60
        return send(res, 201, {
          token: `ghs_test_${minted}`,
          expires_at: new Date(Date.now() + minutes * 60 * 1000).toISOString(),
        })
      }
      if (req.method === 'GET' && /^\/repos\/acme\/[^/]+\/installation$/.test(req.url)) {
        const name = req.url.split('/')[3]
        return name === 'missing' ? send(res, 404, { message: 'Not Found' }) : send(res, 200, { id: 67890 })
      }
      send(res, 404, { message: 'Not Found' })
    })
  })
  .listen(0, '127.0.0.1', function () {
    fs.writeFileSync(portFile, String(this.address().port))
  })
EOF
  node "${sandbox}/api.js" "${sandbox}/port" "${sandbox}/api-log" &
  api_pid=$!
  for _ in $(seq 1 200); do
    [ -s "${sandbox}/port" ] && break
    sleep 0.05
  done
  export MARONIUM_HELPER_API_BASE="http://127.0.0.1:$(cat "${sandbox}/port")"
}

teardown() {
  "${helper}" stop >/dev/null 2>&1 || true
  kill "${api_pid}" >/dev/null 2>&1 || true
  rm -rf "${sandbox}"
}

stat_mode() {
  case "$(uname -s)" in
    Darwin) stat -f '%Lp' "${1}" ;;
    *) stat -c '%a' "${1}" ;;
  esac
}

api_requests() {
  jq -r "${1}" "${sandbox}/api-log"
}

@test "prints an installation token scoped to the requested repository" {
  run "${helper}" token acme/widgets

  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_1" ]
  [ "$(api_requests 'select(.method == "POST") | .url')" = "/app/installations/67890/access_tokens" ]
  [ "$(api_requests 'select(.method == "POST") | .body.repositories | join(",")')" = "widgets" ]
  [ "$(api_requests 'select(.method == "POST") | .body.permissions | to_entries | sort_by(.key) | map("\(.key)=\(.value)") | join(" ")')" = "actions=read checks=read contents=write issues=write metadata=read pull_requests=write statuses=write" ]
}

@test "reuses a cached token while it has more than ten minutes left" {
  run "${helper}" token acme/widgets
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_1" ]

  run "${helper}" token acme/widgets
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_1" ]
  [ "$(jq -s '[.[] | select(.method == "POST")] | length' "${sandbox}/api-log")" -eq 1 ]
}

@test "mints a new token when the cached one is within ten minutes of expiring" {
  run "${helper}" token acme/short
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_1" ]

  run "${helper}" token acme/short
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_2" ]
  [ "$(jq -s '[.[] | select(.method == "POST")] | length' "${sandbox}/api-log")" -eq 2 ]
}

@test "refuses a repository outside the installation's account with a reason" {
  run "${helper}" token otherorg/widgets

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"acme"* ]]
  [ "$(jq -s '[.[] | select(.method == "POST")] | length' "${sandbox}/api-log" 2>/dev/null)" -eq 0 ]
}

@test "refuses a repository the installation does not cover with a reason" {
  run "${helper}" token acme/missing

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"does not cover"* ]]
  [ "$(jq -s '[.[] | select(.method == "POST")] | length' "${sandbox}/api-log")" -eq 1 ]
}

@test "answers the git credential helper for github.com with a Bot token" {
  run bash -c 'printf "protocol=https\nhost=github.com\npath=acme/widgets.git\n" | "${helper}" get'

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"username=x-access-token"* ]]
  [[ "${output}" == *"password=ghs_test_1"* ]]
}

@test "stays silent for a host other than github.com" {
  run bash -c 'printf "protocol=https\nhost=example.com\npath=acme/widgets.git\n" | "${helper}" get'

  [ "${status}" -eq 0 ]
  [ "${output}" = "" ]
}

@test "refuses without the local config file" {
  rm "${HOME}/.config/maronium/helper.json"

  run "${helper}" token acme/widgets

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"helper.json"* ]]
}

@test "reads the App key from 1Password once across repositories" {
  run "${helper}" token acme/widgets
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_1" ]

  run "${helper}" token acme/gadgets
  [ "${status}" -eq 0 ]
  [ "${output}" = "ghs_test_2" ]
  [ "$(wc -l <"${sandbox}/op-reads" | tr -d ' ')" -eq 1 ]
}

@test "keeps the state directory and socket owner-only" {
  # A leftover directory from an older helper may be world-readable.
  mkdir -p "${HOME}/.local/state/maronium"
  chmod 755 "${HOME}/.local/state/maronium"

  run "${helper}" token acme/widgets

  [ "${status}" -eq 0 ]
  [ "$(stat_mode "${HOME}/.local/state/maronium")" = "700" ]
  [ "$(stat_mode "${HOME}/.local/state/maronium/helper.sock")" = "600" ]
}
