#!/usr/bin/env bats
#
# Verifies the question shape check: a question that breaks a mechanical rule
# goes back to the agent with the reason before the human sees it, a check
# that can misjudge only warns, and a session's question is never sent back
# more than twice in a row. Also verifies that the OpenCode plugin applies the
# check to the question tool and leaves every other tool alone.
#
# Usage: bats .github/testdata/opencode-question-shape.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  check="${repo_root}/dot_config/opencode/question-shape.js"
  plugin="${repo_root}/dot_config/opencode/plugins/question-shape.js"
}

# A question that meets every rule; each test changes one field of it.
well_formed='{
  "header": "失敗時の対応",
  "question": "夜間の書き出しが失敗したとき、どう対応しますか。",
  "options": [
    { "label": "推奨 失敗をメールで知らせる", "description": "数分で気づけて、何も消しません。" },
    { "label": "そのままにする", "description": "作業はありませんが、翌朝まで気づけません。" }
  ]
}'

# Prints the check's result for one question as `errors=<n> warnings=<n>`,
# then each message on its own line.
#   $1 a node expression that edits `q`, the well-formed question
check_question() {
  node --input-type=module -e '
    const [check, base, edit] = process.argv.slice(1);
    const { checkQuestions } = await import(check);
    const q = JSON.parse(base);
    new Function("q", edit)(q);
    const { errors, warnings } = checkQuestions([q]);
    console.log(`errors=${errors.length} warnings=${warnings.length}`);
    for (const m of [...errors, ...warnings]) console.log(m);
  ' "${check}" "${well_formed}" "$1"
}

# Prints `blocked` or `shown` for each attempt in one session, one per line.
#   $1 a node expression that edits `q`, $2 the number of attempts
gate_attempts() {
  node --input-type=module -e '
    const [check, base, edit, attempts] = process.argv.slice(1);
    const { createQuestionGate } = await import(check);
    const gate = createQuestionGate();
    for (let i = 0; i < Number(attempts); i++) {
      const q = JSON.parse(base);
      new Function("q", edit)(q);
      console.log(gate.review("session-1", [q]).blocked ? "blocked" : "shown");
    }
  ' "${check}" "${well_formed}" "$1" "$2"
}

@test "a well-formed Japanese question has no error and no warning" {
  run check_question ''
  [ "$status" -eq 0 ]
  [ "$output" = "errors=0 warnings=0" ]
}

@test "a question with no kana is an error that asks for Japanese" {
  run check_question 'q.question = "How should the nightly export respond to a failure?"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *Japanese* ]]
}

@test "a question of three sentences is an error, and two sentences are not" {
  run check_question 'q.question = "書き出しが失敗しました。原因は容量不足です。どう対応しますか？"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *sentences* ]]
  run check_question 'q.question = "書き出しが失敗しました。どう対応しますか？"'
  [ "$output" = "errors=0 warnings=0" ]
}

@test "an option with no description is an error that names the option" {
  run check_question 'q.options[1].description = " "'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *"そのままにする"* ]]
}

@test "a question with no recommended option is an error" {
  run check_question 'q.options[0].label = "失敗をメールで知らせる"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *recommended* ]]
}

@test "a question with two recommended options is an error" {
  run check_question 'q.options[1].label = "推奨 そのままにする"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *recommended* ]]
}

@test "a recommendation marked in parentheses is an error, in either language" {
  run check_question 'q.options[0].label = "失敗をメールで知らせる（推奨）"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *parentheses* ]]
  run check_question 'q.options[0].label = "失敗をメールで知らせる (Recommended)"'
  [ "${lines[0]}" = "errors=1 warnings=0" ]
  [[ "${lines[1]}" == *parentheses* ]]
}

@test "a recommendation marked in the description counts" {
  run check_question 'q.options[0].label = "失敗をメールで知らせる"; q.options[0].description = "推奨。数分で気づけます。"'
  [ "$output" = "errors=0 warnings=0" ]
}

@test "an internal ID such as A-12 only warns, naming the ID" {
  run check_question 'q.question = "A-12 の書き出しが失敗したとき、どう対応しますか。"'
  [ "${lines[0]}" = "errors=0 warnings=1" ]
  [[ "${lines[1]}" == *A-12* ]]
}

@test "parentheses other than a recommendation only warn" {
  run check_question 'q.options[1].description = "作業はありません（翌朝まで気づけません）。"'
  [ "${lines[0]}" = "errors=0 warnings=1" ]
  [[ "${lines[1]}" == *parentheses* ]]
}

@test "a question that breaks a rule is blocked twice in a row, then shown on the third attempt" {
  run gate_attempts 'q.options[0].label = "失敗をメールで知らせる"' 3
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'blocked\nblocked\nshown')" ]
}

@test "a shown question resets the count, so the next broken question is blocked again" {
  run node --input-type=module -e '
    const [check, base] = process.argv.slice(1);
    const { createQuestionGate } = await import(check);
    const gate = createQuestionGate();
    const good = JSON.parse(base);
    const bad = { ...JSON.parse(base), question: "How should it respond?" };
    for (const q of [bad, good, bad]) console.log(gate.review("s", [q]).blocked ? "blocked" : "shown");
  ' "${check}" "${well_formed}"
  [ "$output" = "$(printf 'blocked\nshown\nblocked')" ]
}

@test "blocks in one session do not count toward another session" {
  run node --input-type=module -e '
    const [check, base] = process.argv.slice(1);
    const { createQuestionGate } = await import(check);
    const gate = createQuestionGate();
    const bad = { ...JSON.parse(base), question: "How should it respond?" };
    gate.review("a", [bad]);
    gate.review("a", [bad]);
    console.log(gate.review("b", [bad]).blocked ? "blocked" : "shown");
  ' "${check}" "${well_formed}"
  [ "$output" = blocked ]
}

# Loads the plugin with a stand-in for OpenCode's API, runs one tool call
# through its hooks, and prints `blocked: <reason>` or `shown: <result content>`.
#   $1 tool name, $2 a node expression that edits `q`, the well-formed question
plugin_call() {
  node --input-type=module -e '
    const [plugin, base, tool, edit] = process.argv.slice(1);
    const hooks = {};
    const api = { tool: { hook: async (name, fn) => ((hooks[name] = fn), { dispose: async () => {} }) } };
    await (await import(plugin)).default.setup(api);
    const q = JSON.parse(base);
    new Function("q", edit)(q);
    const call = { tool, sessionID: "s", agent: "build", messageID: "m", id: "c1", input: { questions: [q] } };
    try {
      await hooks["execute.before"](call);
    } catch (error) {
      console.log(`blocked: ${error.message}`);
      process.exit(0);
    }
    const after = { ...call, status: "completed", result: { content: "User has answered your questions." } };
    await hooks["execute.after"](after);
    console.log(`shown: ${after.result.content}`);
  ' "${plugin}" "${well_formed}" "$1" "$2"
}

@test "the plugin sends a question with no kana back to the agent with the reason" {
  run plugin_call question 'q.question = "How should it respond?"'
  [ "$status" -eq 0 ]
  [[ "$output" == "blocked: "*Japanese* ]]
}

@test "the plugin shows a question with an internal ID and adds the warning to its result" {
  run plugin_call question 'q.question = "A-12 の書き出しが失敗したとき、どう対応しますか。"'
  [ "$status" -eq 0 ]
  [[ "$output" == "shown: User has answered your questions."*A-12* ]]
}

@test "the plugin leaves a tool other than question alone" {
  run plugin_call shell 'q.question = "How should it respond?"'
  [ "$status" -eq 0 ]
  [ "$output" = "shown: User has answered your questions." ]
}
