#!/usr/bin/env bats
#
# Verifies the srt sandbox plugin end to end: a command goes through the
# plugin's shell hook the way OpenCode runs it, as `<shell> -c <command>` with
# the hook's environment, and the test checks what that command can read,
# write, and send.
#
# The plugin is deployed into a temporary directory the way chezmoi lays it
# out. Tests that need a working sandbox run only on macOS with Bun, which
# installs srt from the plugin's lockfile; tests that need GitHub run only
# with a gh login. The fail-closed test runs everywhere.
#
# Usage: bats .github/testdata/srt-sandbox-plugin.bats

setup_file() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export SRT_PLUGIN_SOURCE="${repo_root}/dot_config/opencode/plugins/srt-sandbox"
  export SRT_PLUGIN="${BATS_FILE_TMPDIR}/plugin"
  deploy_plugin "${SRT_PLUGIN}"
  if [ "$(uname -s)" = Darwin ] && command -v bun >/dev/null; then
    (cd "${SRT_PLUGIN}" && bun install --frozen-lockfile >/dev/null 2>&1) && export SRT_READY=1
  fi
}

setup() {
  work="$(cd "$(mktemp -d)" && pwd -P)"
  probes=()
}

teardown() {
  rm -rf "${work}"
  [ -z "${home_work:-}" ] || rm -rf "${home_work}"
  # A probe that a failing test let through must not stay in the owner's home.
  for path in "${probes[@]}"; do rm -f "${path}"; done
}

# Sets probe_path to a file name in directory $1 that does not exist yet, and
# removes it at teardown.
probe() {
  probe_path="$1/.srt-sandbox-probe.$$.${RANDOM}"
  probes+=("${probe_path}")
}

# A directory under the home directory, outside every temporary and cache
# directory, so only the working-tree rule can make it writable.
outside_temp() {
  home_work="$(mktemp -d "${HOME}/.srt-sandbox-test.XXXXXX")"
}

# Lays the plugin source out as chezmoi deploys it.
deploy_plugin() {
  mkdir -p "$1"
  cp "${SRT_PLUGIN_SOURCE}"/*.js "${SRT_PLUGIN_SOURCE}"/package.json "${SRT_PLUGIN_SOURCE}"/bun.lock "$1"/
  cp "${SRT_PLUGIN_SOURCE}/executable_zsh" "$1/zsh"
  chmod +x "$1/zsh"
}

needs_sandbox() {
  [ -n "${SRT_READY:-}" ] || skip "needs macOS with Bun to install srt"
}

needs_gh_login() {
  gh auth token >/dev/null 2>&1 || skip "needs a gh login"
}

# Runs command $2 in directory $1 through the plugin at $SRT_PLUGIN, the way
# OpenCode does, and passes its output and exit status through.
sandboxed() {
  node --input-type=module -e '
    import { spawn } from "node:child_process";
    const [plugin, cwd, command] = process.argv.slice(1);
    const { default: srt } = await import(`${plugin}/index.js`);
    let hook;
    const cleanup = await srt.setup({
      location: { directory: cwd },
      shell: { hook: async (name, fn) => { if (name === "create.before") hook = fn; return { dispose: async () => {} }; } },
    });
    const event = { command, cwd, timeout: 0, shell: "/bin/zsh", env: { ...process.env } };
    await hook(event);
    // Asynchronous, because the srt proxy runs in this process and must keep serving while the command runs.
    const child = spawn(event.shell, ["-c", event.command], { cwd: event.cwd, env: event.env, stdio: "inherit" });
    const status = await new Promise((done) => child.on("close", done));
    await cleanup?.();
    process.exit(status ?? 1);
  ' "${SRT_PLUGIN}" "$1" "$2"
}

# Runs command $2 in directory $1 in the sandbox and prints only the
# command's own exit status, so a test can tell a refusal inside the sandbox
# from a harness that never ran the command.
status_in_sandbox() {
  # A subshell, so a redirect inside $2 that fails reports into /dev/null too.
  sandboxed "$1" "( $2 ) >/dev/null 2>&1; echo \"exit=\$?\""
}

new_clone() {
  git init --quiet "$1"
  git -C "$1" -c user.email=t@example.com -c user.name=t commit --quiet --allow-empty -m init
  git -C "$1" remote add origin https://github.com/acme/tool.git
}

@test "a command is refused, not run unsandboxed, when srt cannot be loaded" {
  broken="${work}/broken-plugin"
  deploy_plugin "${broken}"
  SRT_PLUGIN="${broken}" run sandboxed "${work}" "touch ${work}/ran"
  [ "$status" -eq 126 ]
  [ ! -e "${work}/ran" ]
}

@test "a sandboxed command cannot read the gh login from the keychain" {
  needs_sandbox
  needs_gh_login
  real="$(gh auth token)"
  run sandboxed "${work}" 'env -u GH_TOKEN -u GITHUB_TOKEN gh auth token 2>&1; echo "exit=$?"'
  [ "$status" -eq 0 ]
  [[ "$output" != *"${real}"* ]] || false
  [[ "${lines[${#lines[@]}-1]}" =~ ^exit=[1-9] ]] || false
}

@test "a sandboxed command cannot reach 1Password" {
  needs_sandbox
  command -v op >/dev/null || skip "needs the 1Password CLI"
  run status_in_sandbox "${work}" 'op whoami'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^exit=[1-9] ]] || false
}

@test "a sandboxed command cannot list the keychain directory" {
  needs_sandbox
  run status_in_sandbox "${work}" 'ls "$HOME/Library/Keychains"'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^exit=[1-9] ]] || false
}

@test "a sandboxed command cannot list ~/.ssh" {
  needs_sandbox
  [ -d "${HOME}/.ssh" ] || skip "no ~/.ssh on this machine"
  run status_in_sandbox "${work}" 'ls "$HOME/.ssh"'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^exit=[1-9] ]] || false
}

@test "a sandboxed command cannot read OpenCode's service password" {
  needs_sandbox
  [ -f "${HOME}/.config/opencode/service.json" ] || skip "no OpenCode service password on this machine"
  run status_in_sandbox "${work}" 'cat "$HOME/.config/opencode/service.json"'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^exit=[1-9] ]] || false
}

@test "GH_TOKEN inside the sandbox is a placeholder, not the gh login" {
  needs_sandbox
  needs_gh_login
  real="$(gh auth token)"
  run sandboxed "${work}" 'printf "%s" "$GH_TOKEN"'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "${real}" ]
}

@test "a gh request from the sandbox reaches GitHub with the real login" {
  needs_sandbox
  needs_gh_login
  login="$(gh api user --jq .login)"
  run sandboxed "${work}" 'gh api user --jq .login'
  [ "$status" -eq 0 ]
  [ "$output" = "${login}" ]
}

@test "a sandboxed command can write and commit in the working tree it runs in" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  run sandboxed "${home_work}/clone" 'echo hi > note && git add note && git -c user.email=t@example.com -c user.name=t commit --quiet -m note && git log --format=%s -1'
  [ "$status" -eq 0 ]
  # The last line, since a global pre-commit hook may print above it.
  [ "${lines[${#lines[@]}-1]}" = note ]
}

@test "a sandboxed command can commit in a linked worktree, whose git directory is elsewhere" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/main"
  git -C "${home_work}/main" worktree add --quiet "${home_work}/wt" -b topic
  run sandboxed "${home_work}/wt" 'git -c user.email=t@example.com -c user.name=t commit --quiet --allow-empty -m wt && git log --format=%s -1'
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = wt ]
}

@test "a sandboxed command can write under the home directory outside its working tree" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  target="${home_work}/beside-the-clone"
  run status_in_sandbox "${home_work}/clone" "touch '${target}'"
  [ "$status" -eq 0 ]
  [ "$output" = exit=0 ]
  [ -e "${target}" ]
}

@test "a sandboxed command can write under the orchestrate-epic record store" {
  needs_sandbox
  store="${HOME}/.local/state/orchestrate-epic"
  mkdir -p "${store}"
  probe "${store}"
  run status_in_sandbox "${work}" "touch '${probe_path}'"
  [ "$status" -eq 0 ]
  [ "$output" = exit=0 ]
  [ -e "${probe_path}" ]
}

# These run code later outside the sandbox: the shell on its next start, the
# agents and git on their next run, and launchd at the next login.
@test "a sandboxed command cannot write a file a shell or tool reads at startup" {
  needs_sandbox
  for file in .zshenv .zprofile .zshrc .zlogin .zlogout .bashrc .bash_profile .bash_login .profile .npmrc .bunfig.toml \
    .cargo/env .cargo/config.toml .vimrc .tmux.conf .tmux.session.conf .Brewfile .myclirc .terraformrc \
    .gradle/gradle.properties .m2/settings.xml; do
    [ -d "$(dirname "${HOME}/${file}")" ] || continue
    # Appending nothing leaves an existing file as it was even if the open succeeded; a missing one is removed at teardown.
    [ -e "${HOME}/${file}" ] || probes+=("${HOME}/${file}")
    run status_in_sandbox "${work}" ": >> '${HOME}/${file}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: ~/${file}"; false; }
  done
}

@test "a sandboxed command cannot create a file where code is loaded from later" {
  needs_sandbox
  for dir in .config .config/git .config/opencode .local/bin .local/share/mise .ssh Library/LaunchAgents .claude .codex \
    .pi/agent .local/share/opencode .local/state/opencode .cache/zsh .cache/gtr .local/share/sheldon \
    .kube .docker .gnupg .gradle/init.d .vim .tmux .ipython .raycast .apm; do
    [ -d "${HOME}/${dir}" ] || continue
    probe "${HOME}/${dir}"
    run status_in_sandbox "${work}" "touch '${probe_path}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: ~/${dir}"; false; }
  done
}

# A credential store the sandbox cannot read must not be replaced either: a
# rewritten AWS config, for one, runs its credential_process outside the sandbox.
@test "a sandboxed command cannot write a credential store it cannot read" {
  needs_sandbox
  for dir in .aws Library/Keychains .config/op "Library/Group Containers/2BUA8C4S2C.com.1password" \
    Library/Containers/com.1password.1password; do
    [ -d "${HOME}/${dir}" ] || continue
    probe "${HOME}/${dir}"
    run status_in_sandbox "${work}" "touch '${probe_path}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: ~/${dir}"; false; }
  done
  for file in .netrc .git-credentials .pi/agent/auth.json; do
    [ -e "${HOME}/${file}" ] || probes+=("${HOME}/${file}")
    run status_in_sandbox "${work}" ": >> '${HOME}/${file}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: ~/${file}"; false; }
  done
}

# zshrc derives its sourced caches and sheldon's files from the XDG base directories when they are set.
@test "a sandboxed command cannot write what the shell sources under relocated XDG directories" {
  needs_sandbox
  outside_temp
  for base in cache data config; do mkdir -p "${home_work}/${base}"; done
  for target in cache/zsh/eval-cache cache/gtr/init-gtr.zsh data/sheldon/plugins.lock config/sheldon/plugins.toml; do
    XDG_CACHE_HOME="${home_work}/cache" XDG_DATA_HOME="${home_work}/data" XDG_CONFIG_HOME="${home_work}/config" \
      run status_in_sandbox "${work}" "mkdir -p '$(dirname "${home_work}/${target}")' && touch '${home_work}/${target}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: ${target}"; false; }
  done
}

@test "a sandboxed command cannot create a file in a PATH directory of the home" {
  needs_sandbox
  outside_temp
  mkdir "${home_work}/bin"
  PATH="${home_work}/bin:${PATH}" run status_in_sandbox "${work}" "touch '${home_work}/bin/git'"
  [[ "$output" =~ ^exit=[1-9] ]] || false
  [ ! -e "${home_work}/bin/git" ]
}

@test "a sandboxed command cannot change the hooks or config of another clone's submodules and worktrees" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  new_clone "${home_work}/other"
  git -C "${home_work}/other" worktree add --quiet "${home_work}/other-wt" -b topic
  mkdir -p "${home_work}/other/.git/modules/sub/hooks"
  for target in modules/sub/hooks/pre-commit modules/sub/config config.worktree worktrees/other-wt/config.worktree; do
    run status_in_sandbox "${home_work}/clone" "touch '${home_work}/other/.git/${target}'"
    [[ "$output" =~ ^exit=[1-9] ]] || { echo "writable: .git/${target}"; false; }
  done
}

@test "a sandboxed command cannot add a git hook or change the git config of another clone" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  new_clone "${home_work}/other"
  run status_in_sandbox "${home_work}/clone" "touch '${home_work}/other/.git/hooks/pre-commit'"
  [[ "$output" =~ ^exit=[1-9] ]] || false
  run status_in_sandbox "${home_work}/clone" "git -C '${home_work}/other' config core.hooksPath /tmp"
  [[ "$output" =~ ^exit=[1-9] ]] || false
  [ ! -e "${home_work}/other/.git/hooks/pre-commit" ]
}

# Git runs hooks and reads its config outside the sandbox the next time the
# owner uses the repository, so a sandboxed command must not change them.
@test "a sandboxed command cannot add a git hook or change the git config of its clone" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  run status_in_sandbox "${home_work}/clone" 'touch .git/hooks/pre-commit'
  [[ "$output" =~ ^exit=[1-9] ]] || false
  run status_in_sandbox "${home_work}/clone" 'git config core.hooksPath /tmp'
  [[ "$output" =~ ^exit=[1-9] ]] || false
  [ ! -e "${home_work}/clone/.git/hooks/pre-commit" ]
}

@test "a sandboxed command in a linked worktree cannot redirect its git directory or set worktree config" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/main"
  git -C "${home_work}/main" worktree add --quiet "${home_work}/wt" -b topic
  run status_in_sandbox "${home_work}/wt" 'printf "gitdir: /tmp/elsewhere\n" > .git'
  [[ "$output" =~ ^exit=[1-9] ]] || false
  run status_in_sandbox "${home_work}/wt" 'touch "$(git rev-parse --git-dir)/config.worktree"'
  [[ "$output" =~ ^exit=[1-9] ]] || false
}

# gh falls back to a plain-text token in hosts.yml when it cannot use the
# keychain. That file must stay readable for gh to start, so the plugin
# refuses every command instead of exposing the token to it.
gh_hosts() {
  gh_dir="${work}/gh"
  mkdir -p "${gh_dir}"
  printf "%s\n" "$1" > "${gh_dir}/hosts.yml"
}

@test "every command is refused while gh keeps a token in plain text" {
  needs_sandbox
  gh_hosts $'github.com:\n    oauth_token: gho_plaintextexample\n    user: someone'
  GH_CONFIG_DIR="${gh_dir}" run sandboxed "${work}" "touch ${work}/ran"
  [ "$status" -eq 126 ]
  [ ! -e "${work}/ran" ]
}

@test "a command runs while gh keeps no token in hosts.yml" {
  needs_sandbox
  gh_hosts $'github.com:\n    user: someone\n    git_protocol: https'
  GH_CONFIG_DIR="${gh_dir}" run sandboxed "${work}" "touch ${work}/ran"
  [ "$status" -eq 0 ]
  [ -e "${work}/ran" ]
}

# Runs commands $2 and $3 one after the other in directory $1 through one
# plugin instance, the way one OpenCode process does, and prints only each
# exit status; the plugin's own messages go to stderr, which is dropped.
sandboxed_twice() {
  node --input-type=module -e '
    import { spawn } from "node:child_process";
    const [plugin, cwd, ...commands] = process.argv.slice(1);
    const { default: srt } = await import(`${plugin}/index.js`);
    let hook;
    const cleanup = await srt.setup({
      location: { directory: cwd },
      shell: { hook: async (name, fn) => { if (name === "create.before") hook = fn; return { dispose: async () => {} }; } },
    });
    for (const command of commands) {
      const event = { command, cwd, timeout: 0, shell: "/bin/zsh", env: { ...process.env } };
      await hook(event);
      const child = spawn(event.shell, ["-c", event.command], { cwd, env: event.env, stdio: "ignore" });
      console.log(`exit=${await new Promise((done) => child.on("close", done))}`);
    }
    await cleanup?.();
    process.exit(0);
  ' "${SRT_PLUGIN}" "$@" 2>/dev/null
}

@test "a command is refused once gh starts keeping a token in plain text mid-session" {
  needs_sandbox
  gh_hosts $'github.com:\n    user: someone'
  GH_CONFIG_DIR="${gh_dir}" run sandboxed_twice "${work}" \
    "printf '    oauth_token: gho_plaintextexample\n' >> '${gh_dir}/hosts.yml'" \
    "touch ${work}/ran"
  [ "${lines[0]}" = exit=0 ]
  [ "${lines[1]}" = exit=126 ]
  [ ! -e "${work}/ran" ]
}

# SSH cannot authenticate inside the sandbox, which hides the SSH keys and
# agent, so git must reach GitHub over HTTPS, where the credential is swapped.
@test "git inside the sandbox reaches an SSH remote of GitHub over HTTPS" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  git -C "${home_work}/clone" remote set-url origin git@github.com:acme/tool.git
  git -C "${home_work}/clone" remote add other ssh://git@github.com/acme/other.git
  run sandboxed "${home_work}/clone" 'git ls-remote --get-url origin; git ls-remote --get-url other'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = https://github.com/acme/tool.git ]
  [ "${lines[1]}" = https://github.com/acme/other.git ]
}

@test "git config the command already passes through the environment is kept" {
  needs_sandbox
  outside_temp
  new_clone "${home_work}/clone"
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=kept \
    run sandboxed "${home_work}/clone" 'git config user.name'
  [ "$status" -eq 0 ]
  [ "$output" = kept ]
}
