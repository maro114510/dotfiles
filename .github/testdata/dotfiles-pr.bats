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
case "\${1:-}" in
  source-path)
    printf '%s\n' "${source_dir}"
    ;;
  apply)
    git -C "${source_dir}" rev-parse HEAD >"${sandbox}/apply-head"
    ;;
esac
EOF
  cat >"${sandbox}/bin/gh" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"${sandbox}/gh.log"
if [ "\${1:-}" = "pr" ] && [ "\${2:-}" = "view" ]; then
  [ -f "${sandbox}/pr-url" ] || exit 1
  if [ -f "${sandbox}/pr-closed" ] && [[ "\$*" == *"--json url,state"* ]]; then
    exit 0
  fi
  cat "${sandbox}/pr-url"
  exit 0
fi
if [ -n "\${GH_FAIL:-}" ]; then
  echo "gh failed" >&2
  exit 1
fi
rm -f "${sandbox}/pr-closed"
printf 'https://example.com/pr/1\n' | tee "${sandbox}/pr-url"
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
  [[ "${output}" == *"https://example.com/pr/1"* ]]
  [[ "${output}" == *"dotfiles-pr --finish"* ]]
}

@test "on a merged pull request, --finish switches to main, fast-forwards it, then applies" {
  # What a merge leaves behind: the source still on its PR branch, origin/main ahead.
  git -C "${source_dir}" switch --quiet -c chore/dotfiles-20260101-000000
  printf 'two\n' >>"${seed}/dot_zshrc"
  git -C "${seed}" commit --quiet --no-verify --all --message "merged change"
  git -C "${seed}" push --quiet origin main
  merged="$(git -C "${remote}" rev-parse refs/heads/main)"

  run script --finish

  [ "${status}" -eq 0 ]
  [ "$(git -C "${source_dir}" branch --show-current)" = "main" ]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${merged}" ]
  # The apply saw the merged commit, so the pull ran before it.
  [ "$(cat "${sandbox}/apply-head")" = "${merged}" ]
}

@test "on a diverged source, --finish names the failing pull and applies nothing" {
  printf 'remote\n' >>"${seed}/dot_zshrc"
  git -C "${seed}" commit --quiet --no-verify --all --message "remote change"
  git -C "${seed}" push --quiet origin main
  printf 'local\n' >>"${source_dir}/dot_zshrc"
  git -C "${source_dir}" commit --quiet --no-verify --all --message "local change"
  local_head="$(git -C "${source_dir}" rev-parse HEAD)"

  run script --finish

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"git pull --ff-only failed"* ]]
  [ "$(git -C "${source_dir}" rev-parse HEAD)" = "${local_head}" ]
  [ ! -f "${sandbox}/apply-head" ]
}

@test "on a branch with uncommitted edits, --finish names the failing switch and applies nothing" {
  printf 'main\n' >>"${source_dir}/dot_zshrc"
  git -C "${source_dir}" commit --quiet --no-verify --all --message "main change"
  git -C "${source_dir}" switch --quiet -c feat/unmerged HEAD~1
  printf 'branch\n' >>"${source_dir}/dot_zshrc"

  run script --finish

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"git switch main failed"* ]]
  [ "$(git -C "${source_dir}" branch --show-current)" = "feat/unmerged" ]
  [ ! -f "${sandbox}/apply-head" ]
}

@test "--finish refuses a commit message" {
  run script --finish "feat: extra"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"--finish takes no commit message"* ]]
  [ "$(git -C "${source_dir}" branch --show-current)" = "main" ]
  [ ! -f "${sandbox}/apply-head" ]
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

@test "refuses to commit onto a branch it did not create" {
  git -C "${source_dir}" switch --quiet -c feat/unrelated
  printf 'two\n' >>"${source_dir}/dot_zshrc"

  run script "feat: unrelated"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"chore/dotfiles-"* ]]
  [ "$(git -C "${source_dir}" log -1 --pretty=%s)" = "initial" ]
  [ ! -f "${sandbox}/gh.log" ]
}

@test "reuses the open pull request when a follow-up change is added" {
  printf 'two\n' >>"${source_dir}/dot_zshrc"
  run script "feat: first"
  [ "${status}" -eq 0 ]

  printf 'three\n' >>"${source_dir}/dot_zshrc"
  run script "feat: follow-up"

  [ "${status}" -eq 0 ]
  [ "$(git -C "${source_dir}" log -1 --pretty=%s)" = "feat: follow-up" ]
  [ "$(grep -c -- "pr create" "${sandbox}/gh.log")" -eq 1 ]
  [[ "${output}" == *"https://example.com/pr/1"* ]]
}

@test "retries the push and pull request on a clean helper branch" {
  printf 'two\n' >>"${source_dir}/dot_zshrc"
  GH_FAIL=1 run script "feat: first"
  [ "${status}" -eq 1 ]

  run script "feat: retry"

  [ "${status}" -eq 0 ]
  [ -z "$(git -C "${source_dir}" status --porcelain)" ]
  [ "$(grep -c -- "pr create" "${sandbox}/gh.log")" -eq 2 ]
  [[ "${output}" == *"https://example.com/pr/1"* ]]
}

@test "opens a new pull request when the branch's previous one was merged" {
  printf 'two\n' >>"${source_dir}/dot_zshrc"
  run script "feat: first"
  [ "${status}" -eq 0 ]
  touch "${sandbox}/pr-closed"

  printf 'three\n' >>"${source_dir}/dot_zshrc"
  run script "feat: after merge"

  [ "${status}" -eq 0 ]
  [ "$(grep -c -- "pr create" "${sandbox}/gh.log")" -eq 2 ]
}
