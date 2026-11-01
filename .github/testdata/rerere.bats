#!/usr/bin/env bats
#
# Verifies that the chezmoi-managed Git config records conflict resolutions,
# replays them in another worktree, and leaves the replay out of the index.
#
# Each test applies a throwaway chezmoi source holding only the managed Git
# config, so the real $HOME and config are never touched.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/rerere.bats
# Set CHEZMOI to the chezmoi binary when it is not on PATH.

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"

  sandbox="$(mktemp -d)"
  home_dir="${sandbox}/home"
  source_dir="${sandbox}/source"
  mkdir -p "${home_dir}" "${source_dir}/dot_config/git"

  cp "${repo_root}/dot_config/git/config.tmpl" "${source_dir}/dot_config/git/"

  cat > "${sandbox}/chezmoi.toml" <<'EOF'
[data]
  gitEmail = "rerere-test@example.com"
  gitWorkDir = ""
  gitPersonalDir = ""
EOF

  HOME="${home_dir}" "${chezmoi_bin}" apply \
    --config "${sandbox}/chezmoi.toml" \
    --source "${source_dir}" \
    --destination "${home_dir}"
}

teardown() {
  rm -rf "${sandbox}"
}

git_with_managed_config() {
  HOME="${home_dir}" XDG_CONFIG_HOME="${home_dir}/.config" git "$@"
}

create_conflicting_repository() {
  repository="${sandbox}/repository"
  git_with_managed_config init --quiet --initial-branch=main "${repository}"
  git_with_managed_config -C "${repository}" config user.email "rerere-test@example.com"
  git_with_managed_config -C "${repository}" config user.name "rerere test"
  printf 'base\n' > "${repository}/conflict.txt"
  git_with_managed_config -C "${repository}" add conflict.txt
  git_with_managed_config -C "${repository}" commit --quiet --no-verify --message "base"

  git_with_managed_config -C "${repository}" switch --quiet -c theirs
  printf 'theirs\n' > "${repository}/conflict.txt"
  git_with_managed_config -C "${repository}" commit --quiet --no-verify --all --message "theirs"
  theirs_commit="$(git_with_managed_config -C "${repository}" rev-parse HEAD)"

  git_with_managed_config -C "${repository}" switch --quiet main
  printf 'ours\n' > "${repository}/conflict.txt"
  git_with_managed_config -C "${repository}" commit --quiet --no-verify --all --message "ours"
  main_commit="$(git_with_managed_config -C "${repository}" rev-parse HEAD)"
}

@test "managed Git config enables rerere without auto-updating the index" {
  run git_with_managed_config config --get rerere.enabled
  [ "${status}" -eq 0 ]
  [ "${output}" = "true" ]

  run git_with_managed_config config --get rerere.autoupdate
  [ "${status}" -eq 0 ]
  [ "${output}" = "false" ]
}

@test "a resolution recorded in one worktree replays in another without staging" {
  create_conflicting_repository

  first_worktree="${sandbox}/first-worktree"
  second_worktree="${sandbox}/second-worktree"
  git_with_managed_config -C "${repository}" worktree add --quiet "${first_worktree}" theirs
  run git_with_managed_config -C "${first_worktree}" merge main
  [ "${status}" -ne 0 ]
  printf 'resolved\n' > "${first_worktree}/conflict.txt"
  git_with_managed_config -C "${first_worktree}" add conflict.txt
  git_with_managed_config -C "${first_worktree}" commit --quiet --no-verify --message "resolve"

  git_with_managed_config -C "${repository}" worktree add --quiet \
    --detach "${second_worktree}" "${theirs_commit}"
  run git_with_managed_config -C "${second_worktree}" merge "${main_commit}"
  [ "${status}" -ne 0 ]
  [ "$(cat "${second_worktree}/conflict.txt")" = "resolved" ]
  [ "$(git_with_managed_config -C "${second_worktree}" diff --name-only --diff-filter=U)" = "conflict.txt" ]
}
