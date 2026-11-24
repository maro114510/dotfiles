#!/usr/bin/env bats
#
# Verifies the managed OpenCode configuration's shell and read rules: commands
# that touch no secret file run, existence checks on env files run, and every
# way of reading a secret file is still denied.
#
# Each test evaluates a command against the `permissions` list the way
# OpenCode 2.3.2 does: the resource is the command's source text, `*` matches
# any run of characters including spaces and `/`, `?` matches one, a pattern
# ending in " *" also matches the bare command, the last matching rule wins,
# and no match asks. OpenCode splits a compound command into simple commands
# and denies the whole when any one is denied, so the helper splits on `&&`,
# `||`, `;`, `|` and newlines and lets the strictest piece win.
#
# Usage: bats .github/testdata/opencode-shell-rules.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  config="${repo_root}/dot_config/opencode/opencode.jsonc"
}

# Prints "<effect> <matching rule resource>" for one check. $1 is the action
# (shell or read) and $2 the resource; for shell the strictest piece wins.
decide() {
  node -e '
    const fs = require("fs");
    const [config, action, resource] = process.argv.slice(1);
    // The file is JSONC: comments and trailing commas are valid in a JS literal.
    const parsed = new Function(`return (${fs.readFileSync(config, "utf8")})`)();
    const matches = (pattern, text) => {
      let p = pattern
        .replace(/[.+^${}()|[\]\\]/g, "\\$&")
        .replace(/\*/g, ".*")
        .replace(/\?/g, ".");
      if (p.endsWith(" .*")) p = p.slice(0, -3) + "( .*)?";
      return new RegExp("^" + p + "$", "s").test(text);
    };
    const decideOne = (text) => {
      let hit = { effect: "ask", resource: "(no rule)" };
      for (const r of parsed.permissions) {
        if (r.action === action && matches(r.resource, text)) hit = r;
      }
      return hit;
    };
    const pieces = action === "shell"
      ? resource.split(/\n|;|&&|\|\||\|/).map((s) => s.trim()).filter(Boolean)
      : [resource];
    const rank = { allow: 0, ask: 1, deny: 2 };
    let worst;
    for (const piece of pieces) {
      const hit = decideOne(piece);
      if (!worst || rank[hit.effect] > rank[worst.effect]) worst = hit;
    }
    console.log(worst.effect + " " + worst.resource);
  ' "${config}" "$1" "$2"
}

shell_effect() {
  decide shell "$1" | cut -d' ' -f1
}

assert_runs() {
  [ "$(shell_effect "$1")" = allow ] || {
    echo "expected allow: $1 -> $(decide shell "$1")" >&2
    return 1
  }
}

assert_denied() {
  [ "$(shell_effect "$1")" = deny ] || {
    echo "expected deny: $1 -> $(decide shell "$1")" >&2
    return 1
  }
}

@test "commands that name no secret file run" {
  assert_runs "git status --short; git diff --stat"
  assert_runs "sed -n 1,30p README.md"
  assert_runs "go build ./..."
  assert_runs "gh issue view 1 --repo o/r"
  assert_runs "docker ps --format '{{.Names}}'"
  assert_runs "test -d node_modules"
  assert_runs "grep -rn foo docs"
}

@test "existence checks on an env file run" {
  assert_runs "ls .env"
  assert_runs "ls -la .env"
  assert_runs "ls .env*"
  assert_runs "ls .env 2>&1"
  assert_runs "ls .env 2>/dev/null"
  assert_runs "ls .env .env.sample 2>&1"
  assert_runs "test -f .env"
  assert_runs "test -f .env.local"
  assert_runs "test -e .env"
  assert_runs "[ -f .env ]"
  assert_runs "[ -e .env ]"
  assert_runs "git check-ignore .env"
  assert_runs "git check-ignore -v .env"
  assert_runs "git check-ignore -v .env 2>&1"
}

@test "bootstrapping an env file from a template runs with a redirect" {
  assert_runs "cp .env.sample .env"
  assert_runs "cp -n .env.sample .env"
  assert_runs "cp .env.sample .env 2>&1"
  assert_runs "cp -n .env.sample .env 2>/dev/null"
  assert_runs "cp .env.example .env 2>&1"
  assert_runs "cp .env.template .env 2>&1"
}

@test "copying a real env file, or a template elsewhere, is still denied" {
  assert_denied "cp .env .env.backup"
  assert_denied "cp ../main/.env .env"
  assert_denied "cp .env /tmp/leak"
  assert_denied "cp .env.sample /tmp/x 2>&1"
}

@test "reading env contents in bash is still denied" {
  assert_denied "cat .env"
  assert_denied "grep X .env"
  assert_denied "source .env"
  assert_denied ". .env"
  assert_denied "sed -n 1p .env"
  assert_denied "head -1 .env"
  assert_denied "cat .env.local"
  assert_denied "cat < .env"
  assert_denied "cat <.env"
  assert_denied "cat dir/.env"
  assert_denied 'cat ".env"'
}

@test "an existence check cannot be turned into a read or a write" {
  assert_denied "git check-ignore --stdin < .env"
  assert_denied "git check-ignore -v --stdin <.env"
  assert_denied "git check-ignore -v --stdin < dir/.env"
  assert_denied "ls .env > .env"
  assert_denied "ls .env >.env"
  assert_denied "ls .env >> dir/.env"
  assert_denied "test -f .env && cat .env"
  assert_denied "ls .env; cat .env"
  assert_denied "ls .env | grep X .env"
}

@test "an existence check next to another secret file is still denied" {
  assert_denied "ls .env .envrc"
  assert_denied "ls .env ~/.ssh/id_rsa"
  assert_denied "ls .env server.pem"
  assert_denied "ls .env credentials.json"
  assert_denied "test -f .env.local; cat ~/.aws/credentials"
}

@test "reads of other secret files in bash are still denied" {
  assert_denied "cat ~/.ssh/id_ed25519"
  assert_denied "cat /Users/u/.ssh/config"
  assert_denied "cat /Users/u/.aws/credentials"
  assert_denied "cat server.pem"
  assert_denied "cat credentials.json"
  assert_denied "cat .envrc"
}

@test "the read tool is still denied on secret files" {
  [ "$(decide read ".env" | cut -d' ' -f1)" = deny ]
  [ "$(decide read "app/.env" | cut -d' ' -f1)" = deny ]
  [ "$(decide read "/Users/u/.ssh/id_rsa" | cut -d' ' -f1)" = deny ]
  [ "$(decide read "/Users/u/.aws/credentials" | cut -d' ' -f1)" = deny ]
  [ "$(decide read "cert/server.pem" | cut -d' ' -f1)" = deny ]
  [ "$(decide read "x/.env.example" | cut -d' ' -f1)" = allow ]
}

@test "a denial names the rule that caused it" {
  run decide shell "cat .env"
  [ "$status" -eq 0 ]
  [ "$output" = "deny * .env *" ]
  run decide shell "cat /Users/u/.ssh/config"
  [ "$output" = "deny */.ssh*" ]
  run decide shell "cat server.pem"
  [ "$output" = "deny *.pem *" ]
}
