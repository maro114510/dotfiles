#!/usr/bin/env bats
#
# Verifies the mechanical writing-rule checks shared by every harness: the
# spacing rule between Japanese characters and alphanumerics, parenthetical
# asides in prose, and `rm` outside the temporary directories. Also verifies
# the DeepSeek Harness plugin that applies them: it sends a reply that breaks
# the spacing rule back to the agent at most twice per human message, warns
# about an aside with the next human message instead of sending the reply
# back, and warns about `rm` after the command has run.
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

# --- parenthetical asides ---

@test "a full-width parenthetical aside is reported" {
  [ "$(check parentheticalAsides '設定を変えた（再起動は不要）。')" = '[{"snippet":"（再起動は不要）"}]' ]
}

@test "a half-width parenthetical aside is reported" {
  [ "$(check parentheticalAsides 'It runs twice (once per apply).')" = '[{"snippet":"(once per apply)"}]' ]
}

@test "parentheses inside code, a link target, or a path are ignored" {
  [ "$(check parentheticalAsides '`f(x)` と [説明](#L24) と [a](</tmp/b (c).md>) を見る')" = '[]' ]
}

@test "prose without parentheses passes" {
  [ "$(check parentheticalAsides '再起動は不要です。')" = '[]' ]
}

# --- rm outside the temporary directories ---

@test "rm on a project file is reported with its path" {
  [ "$(check nonTemporaryRemovals 'rm -f src/old.ts')" = '["src/old.ts"]' ]
}

@test "rm after another command in the same line is reported" {
  [ "$(check nonTemporaryRemovals 'cd repo && rm -rf build')" = '["build"]' ]
}

@test "rm under /tmp, \$TMPDIR, or the macOS temporary folder passes" {
  [ "$(check nonTemporaryRemovals 'rm -rf /tmp/x "${TMPDIR}/y" /private/var/folders/ab/T/z')" = '[]' ]
}

@test "rm of a temporary path that climbs out with .. is reported" {
  [ "$(check nonTemporaryRemovals 'rm -rf /tmp/../etc')" = '["/tmp/../etc"]' ]
}

@test "a shell comment after rm is not reported as a target" {
  [ "$(check nonTemporaryRemovals 'rm -f /tmp/a # old; b')" = '[]' ]
}

@test "a # inside a word does not hide the targets after it" {
  [ "$(check nonTemporaryRemovals 'rm /tmp/x#y src/a')" = '["src/a"]' ]
}

@test "a temporary file whose name holds two dots passes" {
  [ "$(check nonTemporaryRemovals 'rm /tmp/foo..bar')" = '[]' ]
}

@test "rm of a variable whose value is unknown is reported" {
  [ "$(check nonTemporaryRemovals 'rm -rf "$dir"')" = '["\"$dir\""]' ]
}

@test "a command that only mentions rm passes" {
  [ "$(check nonTemporaryRemovals 'trash old.ts && git rm --cached a && echo rm')" = '[]' ]
}

# --- DeepSeek Harness plugin ---

# Runs the plugin's turn-stopping listener the way DSH dispatches it, with a
# stand-in agent whose session log grows as the turn goes, and prints one line
# per message the plugin sent: "steer: <text>" for a send-back, and
# "context: <text>" for one it added to the step a human message opens.
#   $1 JSON array; a string is the agent's reply followed by a turn stop, and
#      {"human": "<text>"} is a new message from the human
reply_turn() {
  node --input-type=module -e '
    const [plugin, script] = process.argv.slice(1);
    const listeners = {};
    (await import(plugin)).apply({ on: (event, listener) => (listeners[event] = listener) }, {});
    const events = [];
    const send = (kind) => (message) => {
      console.log(kind + ": " + message.content[0].text);
      events.push({ type: "user/message", data: message });
    };
    const agent = { session: { snapshotEvents: () => events }, steer: send("steer") };
    for (const item of JSON.parse(script)) {
      if (typeof item === "string") {
        events.push({ type: "assistant/message", data: { message: { content: [{ type: "text", text: item }] } } });
        await listeners["agent/turn-stopping"]({ agent, turn: 1, signal: new AbortController().signal });
      } else {
        const human = { role: "user", source: { kind: "user" }, content: [{ type: "text", text: item.human }] };
        const proposed = { agent, messages: [human], turn: 2, step: 1, signal: new AbortController().signal };
        const decision = await listeners["agent/pre-step"](proposed, async () => ({ kind: "enter", messages: [human] }));
        for (const message of decision.messages) {
          if (message !== human) console.log("context: " + message.content[0].text);
          events.push({ type: "user/message", data: message });
        }
      }
    }
  ' "${plugin}" "$1"
}

# Runs the plugin's tools/post-execute listener on one bash call and prints
# the decision kind, then the texts of the contexts it added.
#   $1 the shell command
bash_call() {
  node --input-type=module -e '
    const [plugin, command] = process.argv.slice(1);
    const listeners = {};
    (await import(plugin)).apply({ on: (event, listener) => (listeners[event] = listener) }, {});
    const exec = { name: "bash", arguments: { command }, agent: {} };
    const decision = await listeners["tools/post-execute"](exec, {}, async () => ({ kind: "accept" }));
    console.log(decision.kind);
    for (const context of decision.additionalContexts ?? []) console.log(context.content[0].text);
  ' "${plugin}" "$1"
}

@test "a reply breaking the spacing rule is sent back with the reason and its rewrite closes the turn" {
  run reply_turn '["結果は2 点です","結果は2点です"]'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == steer:* ]]
  [[ "${lines[0]}" == *'2 点'* ]]
}

@test "a reply with the spacing only inside a code span closes the turn unchanged" {
  run reply_turn '["例は`2 点`です"]'
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "a reply with a parenthetical aside closes the turn, and the next human message carries a warning" {
  run reply_turn '["設定を変えた（再起動は不要）。",{"human":"次へ"}]'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == context:* ]]
  [[ "${lines[0]}" == *'（再起動は不要）'* ]]
}

@test "a reply without an aside adds nothing to the next human message" {
  run reply_turn '["設定を変えた。",{"human":"次へ"}]'
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "a reply sent back twice closes the turn on the third attempt" {
  run reply_turn '["2 点","3 点","4 点"]'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == steer:* ]]
  [[ "${lines[1]}" == steer:* ]]
}

@test "a new message from the human allows two more send-backs" {
  run reply_turn '["2 点","3 点","4 点",{"human":"次へ"},"5 点"]'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[2]}" == *'5 点'* ]]
}

@test "rm outside the temporary directories runs and adds a warning" {
  run bash_call 'rm -f src/old.ts'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = accept ]
  [[ "${lines[1]}" == *'src/old.ts'* ]]
  [[ "${lines[1]}" == *trash* ]]
}

@test "rm under /tmp runs without a warning" {
  run bash_call 'rm -rf /tmp/x'
  [ "$status" -eq 0 ]
  [ "${output}" = accept ]
}
