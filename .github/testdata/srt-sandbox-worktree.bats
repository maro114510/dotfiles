#!/usr/bin/env bats
#
# Verifies how the srt sandbox plugin finds the working tree a command runs
# in: the tree it may write to, the git directory its commits go to, and the
# GitHub repository that decides its credential.
#
# Every test builds its own repositories in a temporary directory.
#
# Usage: bats .github/testdata/srt-sandbox-worktree.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  policy="${repo_root}/dot_config/opencode/plugins/srt-sandbox/policy.js"
  sandbox="$(cd "$(mktemp -d)" && pwd -P)"
}

teardown() {
  rm -rf "${sandbox}"
}

# Prints the working tree found from directory $1 as JSON.
work_tree_at() {
  node --input-type=module -e '
    const policy = await import(process.argv[1]);
    console.log(JSON.stringify(policy.workTreeAt(process.argv[2])));
  ' "${policy}" "$1"
}

new_repo() {
  git init --quiet "$1"
  git -C "$1" -c user.email=t@example.com -c user.name=t commit --quiet --allow-empty -m init
}

@test "a subdirectory of a clone gives the clone's top, its .git, and its GitHub repository" {
  new_repo "${sandbox}/main"
  git -C "${sandbox}/main" remote add origin https://github.com/acme/tool.git
  mkdir "${sandbox}/main/src"
  run work_tree_at "${sandbox}/main/src"
  [ "$status" -eq 0 ]
  [ "$output" = "{\"top\":\"${sandbox}/main\",\"gitDir\":\"${sandbox}/main/.git\",\"repo\":{\"owner\":\"acme\",\"name\":\"tool\"}}" ]
}

@test "a linked worktree gives its own top and the shared .git of the main clone" {
  new_repo "${sandbox}/main"
  git -C "${sandbox}/main" remote add origin git@github.com:acme/tool.git
  git -C "${sandbox}/main" worktree add --quiet "${sandbox}/wt" -b topic
  run work_tree_at "${sandbox}/wt"
  [ "$output" = "{\"top\":\"${sandbox}/wt\",\"gitDir\":\"${sandbox}/main/.git\",\"repo\":{\"owner\":\"acme\",\"name\":\"tool\"}}" ]
}

@test "a clone whose origin is not on GitHub gives no repository" {
  new_repo "${sandbox}/main"
  git -C "${sandbox}/main" remote add origin https://gitlab.com/acme/tool.git
  run work_tree_at "${sandbox}/main"
  [ "$output" = "{\"top\":\"${sandbox}/main\",\"gitDir\":\"${sandbox}/main/.git\",\"repo\":null}" ]
}

@test "a directory outside any repository gives no working tree" {
  mkdir "${sandbox}/plain"
  run work_tree_at "${sandbox}/plain"
  [ "$output" = null ]
}
