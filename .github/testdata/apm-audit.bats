#!/usr/bin/env bats
#
# Verifies that the last run-after script reports a failed APM deployment and
# stays quiet when APM is absent.
#
# Usage: bats .github/testdata/apm-audit.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  script="${repo_root}/run_after_zz-apm-audit.sh"
  sandbox="$(mktemp -d /tmp/apm-audit.XXXXXX)"
  export HOME="${sandbox}/home"
  mkdir -p "${HOME}/.apm" "${sandbox}/bin"
  bash_bin="$(command -v bash)"
  expected_cwd="$(cd "${HOME}/.apm" && pwd -P)"
}

teardown() {
  rm -rf "${sandbox}"
}

write_apm() {
  exit_code="$1"
  cat >"${sandbox}/bin/apm" <<STUB
#!/bin/sh
pwd -P >"${sandbox}/audit-cwd"
exit ${exit_code}
STUB
  chmod +x "${sandbox}/bin/apm"
}

@test "a failing audit prints the failure and exits non-zero" {
  write_apm 1

  PATH="${sandbox}/bin" run "${bash_bin}" "${script}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"apm audit failed"* ]]
  [ "$(cat "${sandbox}/audit-cwd")" = "${expected_cwd}" ]
}

@test "a passing audit exits zero and prints nothing" {
  write_apm 0

  PATH="${sandbox}/bin" run "${bash_bin}" "${script}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "" ]
  [ "$(cat "${sandbox}/audit-cwd")" = "${expected_cwd}" ]
}

@test "no apm on the path prints nothing and exits zero" {
  PATH="${sandbox}/bin" run "${bash_bin}" "${script}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "" ]
}
