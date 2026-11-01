#!/usr/bin/env bats
#
# Verifies that dotfiles-pr.sh turns uncommitted chezmoi source changes into a
# pull request without ever committing on main.
#
# Every test runs against bare repositories inside a sandbox, with stubbed
# chezmoi and gh, so nothing leaves the machine and no real source is touched.
#
# Usage: bats .github/testdata/dotfiles-pr.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  sandbox="$(mktemp -d)"

  remote="${sandbox}/origin.git"
  git init --quiet --bare --initial-branch=main "${remote}"

  seed="${sandbox}/seed"
  git clone --quiet "${remote}" "${seed}"
  git -C "${seed}" config user.email "pr-test@example.com"
  git -C "${seed}" config user.name "pr test"
  printf 'one\n' >"${seed}/dot_zshrc"
  git -C "${seed}" add dot_zshrc
  # gitleaks runs at commit time; it is not under test here.
  git -C "${seed}" commit --quiet --no-verify --message "initial"
  git -C "${seed}" push --quiet origin main

  source_dir="${sandbox}/source"
  git clone --quiet "${remote}" "${source_dir}"
  git -C "${source_dir}" config user.email "pr-test@example.com"
  git -C "${source_dir}" config user.name "pr test"

  mkdir -p "${sandbox}/bin"
  cat >"${sandbox}/bin/chezmoi" <<EOF
#!/bin/bash
[ "\${1:-}" = "source-path" ] && printf '%s\n' "${source_dir}"
EOF
  cat >"${sandbox}/bin/gh" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"${sandbox}/gh.log"
EOF
  chmod +x "${sandbox}/bin/chezmoi" "${sandbox}/bin/gh"
  PATH="${sandbox}/bin:${PATH}"
}

teardown() {
  rm -rf "${sandbox}"
}

script() {
  bash "${repo_root}/dot_local/bin/executable_dotfiles-pr.sh" "$@"
}

@test "commits uncommitted changes on a PR branch and opens a pull request" {
  printf 'two\n' >>"${source_dir}/dot_zshrc"

  run script "feat: add two"

  [ "${status}" -eq 0 ]
  branch="$(git -C "${source_dir}" branch --show-current)"
  [[ "${branch}" == chore/dotfiles-* ]]
  [ "$(git -C "${source_dir}" log -1 --pretty=%s)" = "feat: add two" ]
  [ -z "$(git -C "${source_dir}" status --porcelain)" ]
  [ "$(git -C "${remote}" rev-parse "refs/heads/${branch}")" = "$(git -C "${source_dir}" rev-parse HEAD)" ]
  grep -q -- "pr create --fill --base main" "${sandbox}/gh.log"
}

@test "refuses when there is nothing to commit" {
  run script "feat: nothing"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"nothing to commit"* ]]
  [ "$(git -C "${source_dir}" branch --show-current)" = "main" ]
}

@test "refuses when local main is not at origin/main" {
  printf 'remote\n' >>"${seed}/dot_zshrc"
  git -C "${seed}" commit --quiet --no-verify --all --message "remote change"
  git -C "${seed}" push --quiet origin main

  printf 'local\n' >>"${source_dir}/dot_zshrc"

  run script "feat: local"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"origin/main"* ]]
  [ "$(git -C "${source_dir}" branch --show-current)" = "main" ]
  [ "$(git -C "${source_dir}" log -1 --pretty=%s)" = "initial" ]
}
