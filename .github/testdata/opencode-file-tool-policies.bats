#!/usr/bin/env bats
#
# Verifies that the managed OpenCode configuration's policies keep the file
# tools away from OpenCode's credentials and from the files that configure or
# implement the sandbox. Policies in the global file outrank any repository's
# configuration, so a repository cannot lift them.
#
# Each test evaluates one tool check against the `policies` list the way
# OpenCode does: the resource is `<action>:<path>`, `*` matches any run of
# characters including `/`, `?` matches one, the last matching statement wins,
# and no match allows.
#
# Usage: bats .github/testdata/opencode-file-tool-policies.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  config="${repo_root}/dot_config/opencode/opencode.jsonc"
}

# Prints the policy effect, deny or allow, for one tool check.
decide() {
  node -e '
    const fs = require("fs");
    const [config, resource] = process.argv.slice(1);
    // The file is JSONC: comments and trailing commas are valid in a JS literal.
    const parsed = new Function(`return (${fs.readFileSync(config, "utf8")})`)();
    const matches = (pattern) =>
      new RegExp(
        "^" +
          pattern
            .split("")
            .map((c) => (c === "*" ? ".*" : c === "?" ? "." : c.replace(/[\\^$.|+()[\]{}]/g, "\\$&")))
            .join("") +
          "$",
      ).test(resource);
    let effect = "allow";
    for (const s of parsed.policies ?? []) {
      if (s.action === "tool.use" && matches(s.resource)) effect = s.effect;
    }
    console.log(effect);
  ' "${config}" "$1"
}

@test "reading OpenCode's service password file by absolute path is denied" {
  run decide "read:/Users/u/.config/opencode/service.json"
  [ "$status" -eq 0 ]
  [ "$output" = deny ]
}

@test "reading OpenCode's provider credential file by absolute path is denied" {
  run decide "read:/Users/u/.local/share/opencode/auth.json"
  [ "$status" -eq 0 ]
  [ "$output" = deny ]
}

@test "reading the credential files relative to a home-directory location is denied" {
  run decide "read:.config/opencode/service.json"
  [ "$output" = deny ]
  run decide "read:.local/share/opencode/auth.json"
  [ "$output" = deny ]
}

@test "editing the global OpenCode config, either extension, is denied" {
  run decide "edit:/Users/u/.config/opencode/opencode.jsonc"
  [ "$output" = deny ]
  run decide "edit:/Users/u/.config/opencode/opencode.json"
  [ "$output" = deny ]
}

@test "editing a global OpenCode plugin, where the sandbox plugin lives, is denied" {
  run decide "edit:/Users/u/.config/opencode/plugins/sandbox/index.ts"
  [ "$output" = deny ]
  run decide "edit:/Users/u/.config/opencode/plugin/sandbox.ts"
  [ "$output" = deny ]
}

@test "editing the global Pi settings or a global Pi extension is denied" {
  run decide "edit:/Users/u/.pi/agent/settings.json"
  [ "$output" = deny ]
  run decide "edit:/Users/u/.pi/agent/extensions/sandbox.ts"
  [ "$output" = deny ]
}

@test "editing the srt settings is denied" {
  run decide "edit:/Users/u/.srt-settings.json"
  [ "$output" = deny ]
}

@test "reading OpenCode's saved tool output stays allowed" {
  run decide "read:/Users/u/.local/share/opencode/tool-output/tool_1"
  [ "$output" = allow ]
}

@test "a repository's own opencode.jsonc stays editable" {
  run decide "edit:opencode.jsonc"
  [ "$output" = allow ]
  run decide "edit:/Users/u/work/repo/.opencode/opencode.jsonc"
  [ "$output" = allow ]
}
