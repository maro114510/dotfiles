#!/usr/bin/env bats
#
# Verifies that the chezmoi-managed Git config activates the pre-push hook, and
# that the hook rejects pushes to main and master on any remote.
#
# Each test applies a throwaway chezmoi source holding only the managed git
# config and the hook, so the real $HOME, config, and hooks are never touched.
# Pushes go to bare repositories inside the sandbox: nothing leaves the machine.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/pre-push-hook.bats
# Set CHEZMOI to the chezmoi binary when it is not on PATH.

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  chezmoi_bin="${CHEZMOI:-chezmoi}"

  sandbox="$(mktemp -d)"
  home_dir="${sandbox}/home"
  source_dir="${sandbox}/source"
  mkdir -p "${home_dir}" "${source_dir}/dot_config/git" "${source_dir}/dot_git_hooks"

  # Copy only the files under test so that no run_ script executes here.
  cp "${repo_root}/dot_config/git/config.tmpl" "${source_dir}/dot_config/git/"
  cp "${repo_root}/dot_git_hooks/executable_pre-push" "${source_dir}/dot_git_hooks/"

  cat > "${sandbox}/chezmoi.toml" <<'EOF'
[data]
  gitEmail = "hook-test@example.com"
  gitWorkDir = ""
  gitPersonalDir = ""
EOF

  HOME="${home_dir}" "${chezmoi_bin}" apply \
    --config "${sandbox}/chezmoi.toml" \
    --source "${source_dir}" \
    --destination "${home_dir}"

  remote_dir="${sandbox}/origin.git"
  git init --quiet --bare --initial-branch=main "${remote_dir}"

  work_dir="${sandbox}/work"
  git init --quiet --initial-branch=main "${work_dir}"
  git -C "${work_dir}" config user.email "hook-test@example.com"
  git -C "${work_dir}" config user.name "hook test"
  # gitleaks runs at commit time; it is not under test here.
  git -C "${work_dir}" commit --quiet --no-verify --allow-empty --message "initial"
  git -C "${work_dir}" remote add origin "${remote_dir}"
}

teardown() {
  rm -rf "${sandbox}"
}

# Runs git with only the sandbox home and its config, the way a Mac that has run
# chezmoi apply uses it.
git_with_managed_config() {
  HOME="${home_dir}" XDG_CONFIG_HOME="${home_dir}/.config" git "$@"
}

@test "chezmoi installs the hook and points core.hooksPath at it" {
  [ -x "${home_dir}/.git_hooks/pre-push" ]

  run git_with_managed_config config --show-origin --get core.hooksPath
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"file:${home_dir}/.config/git/config"* ]]
  [[ "${output}" == *"~/.git_hooks"* ]]
}

@test "a push of HEAD to main is rejected by the hook" {
  run git_with_managed_config -C "${work_dir}" push origin HEAD:main
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Not permitted to push refs/heads/main"* ]]
}

@test "a push of HEAD to refs/heads/main is rejected by the hook" {
  run git_with_managed_config -C "${work_dir}" push origin HEAD:refs/heads/main
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Not permitted to push refs/heads/main"* ]]
}

@test "a push of HEAD to master is rejected by the hook" {
  run git_with_managed_config -C "${work_dir}" push origin HEAD:refs/heads/master
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Not permitted to push refs/heads/master"* ]]
}

@test "a push of HEAD to main on a second remote is rejected by the hook" {
  mirror_dir="${sandbox}/mirror.git"
  git init --quiet --bare --initial-branch=main "${mirror_dir}"
  git -C "${work_dir}" remote add mirror "${mirror_dir}"

  run git_with_managed_config -C "${work_dir}" push mirror HEAD:main
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Not permitted to push refs/heads/main"* ]]
}

@test "a push carrying a feature branch and main is rejected and updates no ref" {
  run git_with_managed_config -C "${work_dir}" push origin HEAD:feature/keep HEAD:main
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Not permitted to push refs/heads/main"* ]]

  run git -C "${work_dir}" ls-remote --heads origin feature/keep
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "a push of HEAD to a feature branch succeeds" {
  run git_with_managed_config -C "${work_dir}" push origin HEAD:feature/keep
  [ "${status}" -eq 0 ]

  run git -C "${work_dir}" ls-remote --heads origin feature/keep
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}
