#!/usr/bin/env bats
#
# Verifies the Pi guard extension: its tool_call handler blocks reads of
# secret files and writes into secret locations, and asks before a major
# destructive shell command, blocking it when the answer is no or when no UI
# can ask. Also verifies that `chezmoi apply` restores a tampered copy.
#
# Each check loads the extension's default export the way Pi does, with a
# stand-in for Pi's API and context, and prints the handler's decision.
#
# Usage: CHEZMOI=/path/to/chezmoi bats .github/testdata/pi-guard-extension.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  extension="${repo_root}/dot_pi/agent/extensions/guard.ts"
  chezmoi_bin="${CHEZMOI:-chezmoi}"
  home_dir="$(mktemp -d)"
  : > "${home_dir}/chezmoi.toml"
  # The real binary, not a version-manager shim that reads HOME, because
  # decide() points HOME at a fake home directory.
  node_bin="$(node -p process.execPath)"
}

teardown() {
  rm -rf "${home_dir}"
}

# Prints "block" or "allow", followed by " asked" when the user was asked.
#   $1 tool name, $2 tool input as JSON, $3 UI answer: yes, no, or none for no UI
decide() {
  HOME=/Users/u "${node_bin}" --experimental-strip-types --no-warnings --input-type=module -e '
    const [extension, toolName, input, answer] = process.argv.slice(1);
    const handlers = [];
    const pi = { on: (event, handler) => event === "tool_call" && handlers.push(handler) };
    (await import(extension)).default(pi);
    let asked = false;
    const ask = async () => ((asked = true), answer === "yes");
    const ctx = {
      cwd: "/Users/u/project",
      hasUI: answer !== "none",
      ui: {
        confirm: ask,
        select: async () => ((await ask()) ? "Yes" : "No"),
        notify: () => {},
      },
    };
    let result;
    for (const handler of handlers) {
      result = await handler({ toolName, toolCallId: "call-1", input: JSON.parse(input) }, ctx);
      if (result?.block) break;
    }
    console.log((result?.block ? "block" : "allow") + (asked ? " asked" : ""));
  ' "${extension}" "$1" "$2" "${3:-none}"
}

read_path() { decide read "{\"path\":\"$1\"}"; }
write_path() { decide write "{\"path\":\"$1\",\"content\":\"x\"}"; }
edit_path() { decide edit "{\"path\":\"$1\",\"edits\":[]}"; }
bash_command() { decide bash "{\"command\":\"$1\"}" "$2"; }

@test "reading .env in the working directory is blocked" {
  run read_path .env
  [ "$status" -eq 0 ]
  [ "$output" = block ]
}

@test "reading a .env variant in a subdirectory or by absolute path is blocked" {
  run read_path app/.env.local
  [ "$output" = block ]
  run read_path /Users/u/other/.env.production
  [ "$output" = block ]
}

@test "reading a committed env template is allowed" {
  run read_path .env.example
  [ "$output" = allow ]
  run read_path app/.env.sample
  [ "$output" = allow ]
  run read_path .env.template
  [ "$output" = allow ]
}

@test "reading key and credential files is blocked" {
  run read_path certs/server.pem
  [ "$output" = block ]
  run read_path certs/server.key
  [ "$output" = block ]
  run read_path backup/id_rsa
  [ "$output" = block ]
  run read_path backup/id_ed25519
  [ "$output" = block ]
  run read_path gcp/credentials.json
  [ "$output" = block ]
}

@test "reading inside .ssh or .aws by tilde, absolute, or relative path is blocked" {
  run read_path "~/.ssh/config"
  [ "$output" = block ]
  run read_path /Users/u/.aws/credentials
  [ "$output" = block ]
  run read_path ../../.ssh/known_hosts
  [ "$output" = block ]
}

@test "reading a symlink whose target is a secret file is blocked" {
  printf 'TOKEN=x\n' > "${home_dir}/.env"
  ln -s "${home_dir}/.env" "${home_dir}/notes.txt"
  run read_path "${home_dir}/notes.txt"
  [ "$output" = block ]
}

@test "reading a secret file in other letter case is blocked, as macOS opens it" {
  run read_path .ENV
  [ "$output" = block ]
  run read_path certs/server.PEM
  [ "$output" = block ]
  run read_path "~/.SSH/config"
  [ "$output" = block ]
}

@test "writing a new file through a symlink to .ssh is blocked" {
  mkdir "${home_dir}/.ssh"
  ln -s "${home_dir}/.ssh" "${home_dir}/link"
  run write_path "${home_dir}/link/config"
  [ "$output" = block ]
}

@test "reading OpenCode's service password file is blocked" {
  run read_path "~/.config/opencode/service.json"
  [ "$output" = block ]
  run read_path /Users/u/.config/opencode/service.json
  [ "$output" = block ]
}

@test "reading OpenCode's provider credential file is blocked" {
  run read_path "~/.local/share/opencode/auth.json"
  [ "$output" = block ]
  run read_path ../.local/share/opencode/auth.json
  [ "$output" = block ]
}

@test "reading an OpenCode credential file in other letter case is blocked" {
  run read_path "~/.Config/OpenCode/Service.json"
  [ "$output" = block ]
}

@test "writing or editing the global OpenCode config, either extension, is blocked" {
  run write_path "~/.config/opencode/opencode.jsonc"
  [ "$output" = block ]
  run edit_path /Users/u/.config/opencode/opencode.json
  [ "$output" = block ]
}

@test "writing or editing a global OpenCode plugin, where the sandbox plugin lives, is blocked" {
  run write_path "~/.config/opencode/plugins/sandbox/index.ts"
  [ "$output" = block ]
  run edit_path /Users/u/.config/opencode/plugin/sandbox.ts
  [ "$output" = block ]
}

@test "writing or editing the global Pi settings or a global Pi extension is blocked" {
  run edit_path "~/.pi/agent/settings.json"
  [ "$output" = block ]
  run write_path /Users/u/.pi/agent/extensions/sandbox.ts
  [ "$output" = block ]
  run edit_path "~/.pi/agent/extensions/guard.ts"
  [ "$output" = block ]
}

@test "writing or editing the srt settings is blocked" {
  run write_path "~/.srt-settings.json"
  [ "$output" = block ]
  run edit_path ../.srt-settings.json
  [ "$output" = block ]
}

@test "reading an ordinary file is allowed" {
  run read_path src/index.ts
  [ "$output" = allow ]
  run read_path docs/environment.md
  [ "$output" = allow ]
}

@test "writing or editing a .env file is blocked" {
  run write_path .env
  [ "$output" = block ]
  run edit_path app/.env.local
  [ "$output" = block ]
}

@test "writing or editing inside .ssh or .aws is blocked" {
  run write_path "~/.ssh/config"
  [ "$output" = block ]
  run edit_path /Users/u/.aws/config
  [ "$output" = block ]
}

@test "writing an ordinary file is allowed" {
  run write_path src/index.ts
  [ "$output" = allow ]
  run edit_path README.md
  [ "$output" = allow ]
}

@test "a destructive command asks and runs when the user says yes" {
  run bash_command "sudo reboot" yes
  [ "$status" -eq 0 ]
  [ "$output" = "allow asked" ]
}

@test "a destructive command asks and is blocked when the user says no" {
  run bash_command "sudo reboot" no
  [ "$output" = "block asked" ]
}

@test "a destructive command is blocked without a UI" {
  run bash_command "sudo reboot" none
  [ "$output" = block ]
}

@test "every major destructive pattern asks" {
  for command in \
    "rm -rf build" \
    "rm -r build" \
    "rm --recursive build" \
    "rm build -R" \
    "git push -f origin main" \
    "git push --force-with-lease origin main" \
    "git push origin +main" \
    "git push -d origin topic" \
    "git push origin --delete topic" \
    "git push origin :topic" \
    "git reset --hard HEAD~1" \
    "git -C repo reset --hard" \
    "gh repo delete me/x --yes" \
    "gh release delete v1" \
    "gh project item-delete 1 --id x" \
    "gh api -X DELETE repos/me/x" \
    "gh api --method delete repos/me/x" \
    "cd /tmp && rm -rf x" \
    "bash -c 'git push -f'"; do
    run bash_command "${command}" no
    [ "$output" = "block asked" ] || { echo "not asked: ${command}"; return 1; }
  done
}

@test "an ordinary command runs without asking" {
  for command in \
    "git push origin main" \
    "git push -u origin topic" \
    "git push --follow-tags" \
    "git reset HEAD~1" \
    "rm build/out.txt" \
    "rm -f build/out.txt" \
    "gh pr list" \
    "gh api repos/me/x" \
    "ls -la"; do
    run bash_command "${command}" no
    [ "$output" = allow ] || { echo "asked: ${command}"; return 1; }
  done
}

@test "chezmoi apply installs the guard as a global Pi extension" {
  run env HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
    --source "${repo_root}" --destination "${home_dir}" apply "${home_dir}/.pi"
  [ "$status" -eq 0 ]
  cmp "${extension}" "${home_dir}/.pi/agent/extensions/guard.ts"
}

@test "chezmoi apply restores a tampered guard" {
  apply() {
    HOME="${home_dir}" "${chezmoi_bin}" --config "${home_dir}/chezmoi.toml" \
      --source "${repo_root}" --destination "${home_dir}" --force apply "${home_dir}/.pi"
  }
  apply
  printf 'export default function () {}\n' > "${home_dir}/.pi/agent/extensions/guard.ts"
  run apply
  [ "$status" -eq 0 ]
  cmp "${extension}" "${home_dir}/.pi/agent/extensions/guard.ts"
}
