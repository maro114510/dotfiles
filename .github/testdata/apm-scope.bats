#!/usr/bin/env bats
#
# Verifies that the repository stops deploying project-scope APM files from its
# root while the user-scope manifest and lockfile under .apm stay managed.
#
# The two root names still appear under the remove type, because .chezmoiremove
# is what deletes them from the home directory; only the file type proves what
# is deployed.
#
# Usage: bats .github/testdata/apm-scope.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
}

@test "chezmoi deploys no root apm.yml or apm.lock.yaml" {
  run "${chezmoi_bin}" --source "${repo_root}" managed --include files

  [ "${status}" -eq 0 ]
  ! grep -qx 'apm.yml' <<<"${output}"
  ! grep -qx 'apm.lock.yaml' <<<"${output}"
}

@test "chezmoi still manages the user-scope manifest and lockfile" {
  run "${chezmoi_bin}" --source "${repo_root}" managed --include files

  [ "${status}" -eq 0 ]
  grep -qx '.apm/apm.yml' <<<"${output}"
  grep -qx '.apm/apm.lock.yaml' <<<"${output}"
}

@test "chezmoiremove removes the two home-directory files" {
  run "${chezmoi_bin}" --source "${repo_root}" managed --include remove

  [ "${status}" -eq 0 ]
  grep -qx 'apm.yml' <<<"${output}"
  grep -qx 'apm.lock.yaml' <<<"${output}"
}
