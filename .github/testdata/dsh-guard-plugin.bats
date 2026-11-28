#!/usr/bin/env bats
#
# Verifies the DSH guard plugin: its guard refuses reads of secret files,
# writes into secret locations and agent configuration, and major destructive
# shell commands, and allows the safe forms of each. A call made through
# run_code reaches the guard as a nested call, which carries a parent token.
# Also verifies that the plugin is delivered as a bundle and that its path
# rules still hold every entry of the Pi guard's.
#
# Each check loads the plugin's exports the way DSH does and prints the
# guard's decision: "refuse" or "allow".
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/dsh-guard-plugin.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  plugin="${repo_root}/dot_local/share/dsh-guard/index.js"
  pi_guard="${repo_root}/dot_pi/agent/extensions/guard.ts"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  work_dir="$(mktemp -d)"
  # Not under the temporary directory, which the rm rule allows without looking at worktrees.
  repo_work_dir="$(mktemp -d "${repo_root}/guard-test.XXXXXX")"
  node_bin="$(node -p process.execPath)"
}

teardown() {
  rm -rf "${work_dir}" "${repo_work_dir}"
}

# Prints "refuse" or "allow".
#   $1 tool name, $2 arguments as JSON, $3 working directory, $4 "nested" for a call made through run_code
decide() {
  HOME=/Users/u "${node_bin}" --input-type=module -e '
    const [plugin, name, args, cwd, nested] = process.argv.slice(1);
    const { decide } = await import(plugin);
    const exec = { name, arguments: JSON.parse(args), ...(nested === "nested" ? { parent: Symbol("run_code") } : {}) };
    console.log(decide(exec, cwd) === undefined ? "allow" : "refuse");
  ' "${plugin}" "$1" "$2" "${3:-/Users/u/project}" "${4:-}"
}

read_path() { decide read "{\"file_path\":\"$1\"}"; }
write_path() { decide write "{\"file_path\":\"$1\",\"content\":\"x\"}"; }
# $1 command, $2 working directory
bash_command() {
  local json
  json="$("${node_bin}" -e 'process.stdout.write(JSON.stringify({ command: process.argv[1] }))' "$1")"
  decide bash "${json}" "${2:-/Users/u/project}"
}

# --- reading ---

@test "reading .env, key files, and credentials is refused" {
  for path in .env app/.env.local /Users/u/other/.env.production certs/server.pem certs/server.key \
    backup/id_rsa backup/id_ed25519 gcp/credentials.json .ENV certs/server.PEM; do
    run read_path "${path}"
    [ "$output" = refuse ] || { echo "allowed: ${path}"; return 1; }
  done
}

@test "reading inside .ssh or .aws, or searching one, is refused" {
  for path in "~/.ssh/config" /Users/u/.aws/credentials ../../.ssh/known_hosts "~/.SSH/config" "~/.ssh"; do
    run read_path "${path}"
    [ "$output" = refuse ] || { echo "allowed: ${path}"; return 1; }
  done
}

@test "reading an env template or an ordinary file is allowed" {
  for path in .env.example app/.env.sample .env.template src/index.ts docs/environment.md; do
    run read_path "${path}"
    [ "$output" = allow ] || { echo "refused: ${path}"; return 1; }
  done
}

@test "reading the OpenCode and DSH credential files is refused" {
  for path in "~/.config/opencode/service.json" "~/.local/share/opencode/auth.json" \
    "~/.dsh/.credentials.yaml" "~/.dsh/plugins/subscriptions/auth.json"; do
    run read_path "${path}"
    [ "$output" = refuse ] || { echo "allowed: ${path}"; return 1; }
  done
}

@test "reading a symlink whose target is a secret file is refused" {
  printf 'TOKEN=x\n' > "${work_dir}/.env"
  ln -s "${work_dir}/.env" "${work_dir}/notes.txt"
  run read_path "${work_dir}/notes.txt"
  [ "$output" = refuse ]
}

@test "every tool that names a path is checked, whatever its argument is called" {
  run decide ops_inspect_local_file '{"path":"~/.ssh/config"}'
  [ "$output" = refuse ]
  run decide read_image '{"file_path":"/Users/u/.aws/x.png"}'
  [ "$output" = refuse ]
  run decide grep '{"pattern":"x","path":"/Users/u/.ssh"}'
  [ "$output" = refuse ]
  run decide ops_read_files '{"files":[{"path":"src/a.ts"},{"path":".env"}]}'
  [ "$output" = refuse ]
  run decide ops_read_files '{"files":[{"path":"src/a.ts"}]}'
  [ "$output" = allow ]
  run decide str_replace_editor '{"command":"view","path":".env"}'
  [ "$output" = refuse ]
}

# --- writing ---

@test "writing a .env file or inside .ssh or .aws is refused" {
  for path in .env app/.env.local "~/.ssh/config" /Users/u/.aws/config; do
    run write_path "${path}"
    [ "$output" = refuse ] || { echo "allowed: ${path}"; return 1; }
  done
}

@test "writing the global DSH, OpenCode, and Pi configuration and plugins is refused" {
  for path in "~/.dsh/AGENTS.md" "~/.dsh/cordis.patch.yml" "~/.dsh/profiles/web/package.json" \
    "~/.dsh/plugins/x/index.js" "~/.config/dsh/package.json" "~/.local/share/dsh-guard/index.js" \
    "~/.config/opencode/opencode.jsonc" "~/.config/opencode/plugins/sandbox/index.ts" \
    "~/.pi/agent/settings.json" "~/.pi/agent/extensions/guard.ts"; do
    run write_path "${path}"
    [ "$output" = refuse ] || { echo "allowed: ${path}"; return 1; }
  done
}

@test "edit, patch, move, and replace tools are checked as writes" {
  run decide edit '{"file_path":"~/.dsh/AGENTS.md","old_string":"a","new_string":"b"}'
  [ "$output" = refuse ]
  run decide apply_patch '{"input":"*** Begin Patch\n*** Update File: ~/.pi/agent/settings.json\n*** End Patch"}'
  [ "$output" = refuse ]
  run decide apply_patch '{"input":"*** Begin Patch\n*** Add File: src/a.ts\n+x\n*** End Patch"}'
  [ "$output" = allow ]
  run decide ops_write_file '{"path":".env","content":"x","expectedRevision":"r"}'
  [ "$output" = refuse ]
  run decide ops_move '{"path":"a.txt","to":"~/.ssh/config","expectedRevision":"r"}'
  [ "$output" = refuse ]
  run decide ops_copy '{"path":"~/.ssh/id_rsa","to":"/tmp/k","expectedRevision":"r"}'
  [ "$output" = refuse ]
  run decide ops_batch '{"operations":[{"op":"remove","path":"~/.ssh/config"}]}'
  [ "$output" = refuse ]
  run decide str_replace_editor '{"command":"create","path":".env","file_text":"x"}'
  [ "$output" = refuse ]
}

@test "writing an ordinary file, a key file, or a repository's own configuration is allowed" {
  for path in src/index.ts README.md certs/server.pem opencode.jsonc .opencode/opencode.jsonc .pi/settings.json .dsh/note.md; do
    run write_path "${path}"
    [ "$output" = allow ] || { echo "refused: ${path}"; return 1; }
  done
}

# --- shell ---

@test "sudo, git reset --hard, gh delete, and gh api DELETE are refused" {
  for command in \
    "sudo reboot" \
    "cd /tmp && sudo rm x" \
    "env FOO=1 sudo ls" \
    "git reset --hard HEAD~1" \
    "git -C repo reset --hard" \
    "gh repo delete me/x --yes" \
    "gh release delete v1" \
    "gh project item-delete 1 --id x" \
    "gh api -X DELETE repos/me/x" \
    "gh api --method delete repos/me/x" \
    "gh api repos/me/x --method=DELETE" \
    "bash -c 'git reset --hard'" \
    "bash -lc \"sudo ls\"" \
    "eval 'sudo ls'" \
    "echo ok; (sudo ls)" \
    "ls \$(sudo cat x)"; do
    run bash_command "${command}"
    [ "$output" = refuse ] || { echo "allowed: ${command}"; return 1; }
  done
}

@test "a force push or a deleting push is refused, and --force-with-lease is allowed" {
  for command in \
    "git push -f origin main" \
    "git push --force origin main" \
    "git push origin +main" \
    "git push -d origin topic" \
    "git push origin --delete topic" \
    "git push origin :topic" \
    "git push --force-with-lease -f origin main" \
    "git -C repo push -fu origin main"; do
    run bash_command "${command}"
    [ "$output" = refuse ] || { echo "allowed: ${command}"; return 1; }
  done
  for command in \
    "git push --force-with-lease origin main" \
    "git push --force-with-lease=main:abc123 --force-if-includes origin main" \
    "git push -u origin topic" \
    "git push --follow-tags" \
    "git push origin main"; do
    run bash_command "${command}"
    [ "$output" = allow ] || { echo "refused: ${command}"; return 1; }
  done
}

@test "an ordinary command is allowed, and a quoted or heredoc mention is not a command" {
  for command in \
    "git reset HEAD~1" \
    "rm build/out.txt" \
    "rm -f build/out.txt" \
    "gh pr list" \
    "gh api repos/me/x" \
    "gh issue comment 5 --body 'delete later'" \
    "ls -la 2>&1 | tail" \
    "git commit -m \"never run sudo or git reset --hard or rm -rf /\"" \
    "echo 'rm -rf /Users/u'" \
    "cat <<'EOF'
sudo reboot
rm -rf /Users/u
EOF"; do
    run bash_command "${command}"
    [ "$output" = allow ] || { echo "refused: ${command}"; return 1; }
  done
}

@test "a heredoc fed to a shell is inspected" {
  run bash_command "bash <<EOF
sudo reboot
EOF"
  [ "$output" = refuse ]
}

@test "a recursive rm of a temporary directory is allowed" {
  for command in \
    "rm -rf /tmp/build" \
    "rm -r /private/tmp/build/out" \
    "rm -fr /var/folders/ab/cd/T/x" \
    "rm --recursive -f /tmp/a /tmp/b" \
    "rm -rf \"\${TMPDIR}/x\"" \
    "rm -rf /tmp/build/*" \
    "rm -rf -- /tmp/build" \
    "cd /tmp && rm -rf build" \
    "cd /tmp/a; cd ..; rm -rf b"; do
    run bash_command "${command}"
    [ "$output" = allow ] || { echo "refused: ${command}"; return 1; }
  done
}

@test "a recursive rm outside temporary directories and worktrees is refused" {
  for command in \
    "rm -rf /" \
    "rm -rf /tmp" \
    "rm -rf /tmp/.." \
    "rm -rf /tmp/../Users/u" \
    "rm -rf /Users/u/project" \
    "rm -r ~/Documents" \
    "rm -rf \$HOME" \
    "rm -rf \$DIR/x" \
    "rm -rf /tmp/ok /Users/u/other" \
    "rm build -R" \
    "cd /tmp && rm -rf ../Users/u" \
    "cd \$X && rm -rf build" \
    "cd && rm -rf build" \
    "git ls-files | xargs rm -rf" \
    "bash -c 'rm -rf /Users/u/x'"; do
    run bash_command "${command}" /Users/u/project
    [ "$output" = refuse ] || { echo "allowed: ${command}"; return 1; }
  done
}

@test "a recursive rm inside a worktree is allowed, but not of its root, its .git, or a directory holding another worktree" {
  main="${repo_work_dir}/repo"
  git init -q "${main}"
  git -C "${main}" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git -C "${main}" worktree add -q "${main}/.wt/topic" -b topic
  for cwd in "${main}" "${main}/.wt/topic"; do
    for command in "rm -rf build" "rm -rf node_modules" "rm -r src/gen" "rm -rf ./out/*"; do
      run bash_command "${command}" "${cwd}"
      [ "$output" = allow ] || { echo "refused in ${cwd}: ${command}"; return 1; }
    done
  done
  for command in "rm -rf ." "rm -rf .git" "rm -rf .git/hooks" "rm -rf .wt" "rm -rf .wt/topic" "rm -rf .."; do
    run bash_command "${command}" "${main}"
    [ "$output" = refuse ] || { echo "allowed in main: ${command}"; return 1; }
  done
  for command in "rm -rf ." "rm -rf ../../.git" "rm -rf .git"; do
    run bash_command "${command}" "${main}/.wt/topic"
    [ "$output" = refuse ] || { echo "allowed in worktree: ${command}"; return 1; }
  done
  run bash_command "rm -rf ${main}/.wt/topic/node_modules" "${main}"
  [ "$output" = allow ]
  run bash_command "rm -rf ${main}/.wt/topic/node_modules" /Users/u/project
  [ "$output" = refuse ]
}

@test "the shell tool's workdir sets where a relative rm target lives" {
  run decide ops_bash '{"command":"rm -rf build","workdir":"/tmp"}' /Users/u/project
  [ "$output" = allow ]
  run decide ops_bash '{"command":"rm -rf build","workdir":"/Users/u/project"}' /Users/u/project
  [ "$output" = refuse ]
}

# --- run_code and registration ---

@test "a nested call made through run_code is refused and allowed like a direct one" {
  run decide read '{"file_path":".env"}' /Users/u/project nested
  [ "$output" = refuse ]
  run decide ops_inspect_local_file '{"path":"~/.ssh/config"}' /Users/u/project nested
  [ "$output" = refuse ]
  run decide bash '{"command":"git reset --hard"}' /Users/u/project nested
  [ "$output" = refuse ]
  run decide read '{"file_path":".env.example"}' /Users/u/project nested
  [ "$output" = allow ]
}

@test "the plugin registers one guard that denies with a reason and leaves other calls alone" {
  run "${node_bin}" --input-type=module -e '
    const { apply, inject } = await import(process.argv[1]);
    let registered;
    const ctx = {
      effect: (setup) => setup(),
      tools: { guard: (guard) => ((registered = guard), () => {}) },
      workingDirectory: { get: () => "/Users/u/project" },
    };
    apply(ctx);
    const agent = { session: {} };
    const deny = registered({ name: "bash", arguments: { command: "sudo ls" }, agent });
    const pass = registered({ name: "bash", arguments: { command: "ls" }, agent });
    console.log(inject.join(","), typeof deny, pass);
  ' "${plugin}"
  [ "$status" -eq 0 ]
  [ "$output" = "tools string undefined" ]
}

# --- delivery ---

@test "the plugin is a bundle with its own plugin row" {
  dir="${repo_root}/dot_local/share/dsh-guard"
  [ "$(jq -r '.name' "${dir}/package.json")" = dsh-guard ]
  [ "$(jq -r '.dsh.bundle.patch' "${dir}/package.json")" = ./cordis.patch.yml ]
  grep -q 'name: dsh-guard' "${dir}/cordis.patch.yml"
  jq -e '.meta.title and .meta.description' "${dir}/locale/en.json" >/dev/null
}

@test "chezmoi apply installs the plugin under the local share directory" {
  home_dir="$(mktemp -d)"
  : > "${home_dir}/chezmoi.toml"
  run env HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" apply "${home_dir}/.local"
  [ "$status" -eq 0 ]
  cmp "${plugin}" "${home_dir}/.local/share/dsh-guard/index.js"
  [ -f "${home_dir}/.local/share/dsh-guard/package.json" ]
  rm -rf "${home_dir}"
}

@test "the path rules hold every entry of the Pi guard's" {
  entries="$(sed -n '/^const SECRET_DIRS/p; /^const UNREADABLE = /p; /^const READABLE = /p; /^const UNWRITABLE = /p' "${pi_guard}" \
    | grep -oE '"[^"]+"|/[^/ ]+/' | sort -u)"
  paths="$(sed -n '/^const UNREADABLE_PATHS/,/^\];$/p; /^const UNWRITABLE_PATHS/,/^\];$/p' "${pi_guard}" | grep -oE '"[^"]+"')"
  [ -n "${entries}" ]
  [ -n "${paths}" ]
  while IFS= read -r entry; do
    grep -qF -- "${entry}" "${plugin}" || { echo "missing: ${entry}"; return 1; }
  done <<<"${entries}
${paths}"
}
