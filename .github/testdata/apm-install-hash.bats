#!/usr/bin/env bats
#
# Verifies that the APM install script re-runs when either the user-scope
# manifest or the lockfile changes.
#
# Usage: bats .github/testdata/apm-install-hash.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  src="$(mktemp -d /tmp/apm-install.XXXXXX)"
  mkdir -p "${src}/dot_apm"
  cp "${repo_root}/run_onchange_after_apm-install.sh.tmpl" "${src}/"
  cp "${repo_root}/dot_apm/apm.yml" "${repo_root}/dot_apm/apm.lock.yaml" "${src}/dot_apm/"
}

teardown() {
  rm -rf "${src}"
}

render() {
  HOME="${src}" "${chezmoi_bin}" --source "${src}" execute-template \
    < "${src}/run_onchange_after_apm-install.sh.tmpl"
}

@test "the rendered script carries a hash of the manifest and the lockfile" {
  run render

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"apm.lock.yaml hash:"* ]]
  [[ "${output}" == *"apm.yml hash:"* ]]
}

@test "a changed manifest changes the rendered script" {
  before="$(render)"
  printf '\n# a new dependency\n' >>"${src}/dot_apm/apm.yml"
  after="$(render)"

  [ "${before}" != "${after}" ]
}

@test "a changed lockfile changes the rendered script" {
  before="$(render)"
  printf '\n# a new pin\n' >>"${src}/dot_apm/apm.lock.yaml"
  after="$(render)"

  [ "${before}" != "${after}" ]
}

@test "unchanged sources render the same script twice" {
  first="$(render)"
  second="$(render)"

  [ "${first}" = "${second}" ]
}
