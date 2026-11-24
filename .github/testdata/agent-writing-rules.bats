#!/usr/bin/env bats
#
# Verifies the mechanical writing-rule checks shared by every harness: the
# spacing rule between Japanese characters and alphanumerics, parenthetical
# asides in prose, and `rm` outside the temporary directories. Also verifies
# the DeepSeek Harness plugin that applies them: it sends a reply that breaks
# the spacing rule back to the agent at most twice per turn, warns about an
# aside without sending the reply back, and warns about `rm` after the command
# has run.
#
# Usage: bats .github/testdata/agent-writing-rules.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  rules="${repo_root}/dot_local/share/agent-writing-rules/rules.mjs"
  plugin="${repo_root}/dot_local/share/agent-writing-rules/dsh/index.js"
}

# Prints the JSON result of one rule.
#   $1 exported function name, $2 its text argument
check() {
  node --input-type=module -e '
    const [rules, fn, text] = process.argv.slice(1);
    console.log(JSON.stringify((await import(rules))[fn](text)));
  ' "${rules}" "$1" "$2"
}

# --- spacing between Japanese and alphanumerics ---

@test "a space between a digit and a following kanji is reported" {
  [ "$(check spacingViolations '結果は2 点です')" = '[{"snippet":"2 点"}]' ]
}

@test "a space between kana and a following Latin letter is reported" {
  [ "$(check spacingViolations 'これは DSH です')" = '[{"snippet":"は D"},{"snippet":"H で"}]' ]
}

@test "Japanese text written without the spaces passes" {
  [ "$(check spacingViolations '結果は2点で、DSHを使う')" = '[]' ]
}

@test "a space inside an inline code span is ignored" {
  [ "$(check spacingViolations '例は`2 点`のとおり')" = '[]' ]
}

@test "a space inside a fenced code block is ignored" {
  [ "$(check spacingViolations $'説明\n```\necho 2 点\n```\n以上')" = '[]' ]
}

@test "a space next to a URL or a path is ignored" {
  [ "$(check spacingViolations '詳細は https://example.com/a と ~/.dsh/AGENTS.md を参照')" = '[]' ]
}

@test "English text without Japanese passes" {
  [ "$(check spacingViolations 'Use 2 spaces in DSH 3')" = '[]' ]
}
