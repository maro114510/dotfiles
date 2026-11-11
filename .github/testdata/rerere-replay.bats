#!/usr/bin/env bats
#
# Verifies that the chezmoi-managed git config enables rerere without
# auto-staging, and that a conflict resolution recorded in one worktree is
# replayed in another worktree of the same repository.
#
# The rendered config is used as GIT_CONFIG_GLOBAL inside a throwaway home, so
# the test proves what `chezmoi apply` deploys rather than what this machine's
# ~/.config/git/config happens to contain.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/rerere-replay.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  sandbox="$(mktemp -d)"
  home_dir="${sandbox}/home"
  mkdir -p "${home_dir}"

  HOME="${home_dir}" "${chezmoi_bin}" \
    --config "${repo_root}/.github/testdata/chezmoi-full.toml" \
    --source "${repo_root}" \
    execute-template < "${repo_root}/dot_config/git/config.tmpl" \
    > "${sandbox}/gitconfig"

  # Worktrees share a repository, and the rerere cache lives in the shared git
  # directory, which is the arrangement this test proves.
  export HOME="${home_dir}"
  export GIT_CONFIG_GLOBAL="${sandbox}/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
}

teardown() {
  rm -rf "${sandbox}"
}

# Builds a repository where merging `topic` conflicts in exactly the same way
# on two sibling branches. No branch has merged yet.
prepare_conflict() {
  repo="${sandbox}/repo"
  git init --quiet --initial-branch=main "${repo}"
  printf 'base\n' > "${repo}/f"
  git -C "${repo}" add f
  git -C "${repo}" commit --quiet --no-verify --message base

  git -C "${repo}" switch --quiet --create topic
  printf 'topic\n' > "${repo}/f"
  git -C "${repo}" commit --quiet --no-verify --all --message topic

  git -C "${repo}" switch --quiet main
  printf 'main\n' > "${repo}/f"
  git -C "${repo}" commit --quiet --no-verify --all --message main

  git -C "${repo}" branch replay-a main
  git -C "${repo}" branch replay-b main
  git -C "${repo}" worktree add --quiet "${sandbox}/a" replay-a
  git -C "${repo}" worktree add --quiet "${sandbox}/b" replay-b
}

# Merges `topic` into the given worktree. A conflict exits non-zero, which is
# the state under test, so the caller always inspects the tree afterwards.
merge_topic() {
  (cd "$1" && git merge --no-edit topic) >/dev/null 2>&1 || true
}

# Resolves the conflict in the first worktree and commits the resolution, which
# records it in the shared rerere cache.
record_resolution() {
  merge_topic "${sandbox}/a"
  printf 'resolved\n' > "${sandbox}/a/f"
  git -C "${sandbox}/a" add f
  git -C "${sandbox}/a" commit --quiet --no-verify --no-edit
}

@test "the rendered git config enables rerere without auto-staging" {
  run git config --file "${sandbox}/gitconfig" --get rerere.enabled
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run git config --file "${sandbox}/gitconfig" --get rerere.autoupdate
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "a resolution recorded in one worktree replays in another" {
  prepare_conflict
  record_resolution

  merge_topic "${sandbox}/b"

  [ "$(cat "${sandbox}/b/f")" = "resolved" ]
  run git -C "${sandbox}/b" diff --name-only --diff-filter=U
  [ "$output" = "f" ]
}

@test "a replayed resolution stays unstaged for review" {
  prepare_conflict
  record_resolution

  merge_topic "${sandbox}/b"

  # Replay must have happened; otherwise the staging assertions below would
  # pass on an unresolved conflict.
  [ "$(cat "${sandbox}/b/f")" = "resolved" ]

  # Three unmerged index stages mean git did not stage the replayed file.
  run git -C "${sandbox}/b" ls-files --stage f
  [ "${#lines[@]}" -eq 3 ]
  run git -C "${sandbox}/b" status --porcelain
  [ "$output" = "UU f" ]
}
