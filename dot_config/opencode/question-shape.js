// Checks the shape of the questions an agent asks the human. Plain data in and
// out, with no OpenCode import, so a Claude Code hook can reuse it.

// Every session counts as Japanese: the shared instructions ask the human in
// Japanese in every session, so no per-session language detection is needed.
const KANA = /[\u3040-\u30ff]/;
// A period ends a sentence only before a space or the end, so `v1.2` and
// `e.g.,` stay one sentence.
const SENTENCE_END = /[。！？!?]+|\.(?=\s|$)/;
const MAX_SENTENCES = 2;
const RECOMMENDED = /推奨|recommended/i;
const PARENTHESIZED = /[(（][^()（）]*[)）]/g;
// An Issue key such as `A-12` or a bare number such as `#162`.
const INTERNAL_ID = /\b[A-Z][A-Z0-9]*-\d+\b|#\d+\b/g;
// After this many sends back in a row, the next question reaches the human
// even if it still breaks a rule, so an agent that cannot comply never loops.
const MAX_BLOCKS = 2;

function sentenceCount(text) {
  return text.split(SENTENCE_END).filter((part) => part.trim() !== "").length;
}

function checkQuestion(q) {
  const errors = [];
  const warnings = [];
  const question = String(q.question ?? "");
  const options = Array.isArray(q.options) ? q.options : [];

  if (!KANA.test(question)) {
    errors.push("Write the question in Japanese: it has no kana.");
  }
  const sentences = sentenceCount(question);
  if (sentences > MAX_SENTENCES) {
    errors.push(`Keep the question to ${MAX_SENTENCES} sentences or fewer: it has ${sentences}.`);
  }
  for (const option of options) {
    if (String(option.description ?? "").trim() === "") {
      errors.push(`Describe the option "${option.label}": its description is empty.`);
    }
  }

  const texts = [question, ...options.flatMap((o) => [String(o.label ?? ""), String(o.description ?? "")])];
  const recommended = options.filter((o) => RECOMMENDED.test(`${o.label ?? ""} ${o.description ?? ""}`));
  if (recommended.length !== 1) {
    errors.push(
      `Mark exactly one option as recommended with 推奨 in its label or description: ${recommended.length} are marked.`,
    );
  }
  const parenthesized = texts.flatMap((text) => text.match(PARENTHESIZED) ?? []);
  if (parenthesized.some((p) => RECOMMENDED.test(p))) {
    errors.push(`Mark the recommendation without parentheses, such as "推奨 <label>".`);
  }
  const asides = parenthesized.filter((p) => !RECOMMENDED.test(p));
  if (asides.length > 0) {
    warnings.push(`Write ${asides.join(", ")} as its own clause instead of in parentheses.`);
  }

  const ids = [...new Set(texts.flatMap((text) => text.match(INTERNAL_ID) ?? []))];
  if (ids.length > 0) {
    warnings.push(`Say what ${ids.join(", ")} is in plain words; the human may not know it.`);
  }
  return { errors, warnings };
}

// Returns the rule violations that send a question back to the agent, and the
// findings that may misjudge, so they only warn.
export function checkQuestions(questions) {
  const errors = [];
  const warnings = [];
  questions.forEach((q, i) => {
    const prefix = questions.length > 1 ? `Question ${i + 1}: ` : "";
    const result = checkQuestion(q);
    errors.push(...result.errors.map((m) => prefix + m));
    warnings.push(...result.warnings.map((m) => prefix + m));
  });
  return { errors, warnings };
}

// Decides, per session, whether a question goes back to the agent or reaches
// the human.
export function createQuestionGate() {
  const blocks = new Map();
  return {
    review(sessionID, questions) {
      const { errors, warnings } = checkQuestions(questions);
      const count = blocks.get(sessionID) ?? 0;
      if (errors.length > 0 && count < MAX_BLOCKS) {
        blocks.set(sessionID, count + 1);
        const message = [
          "The question was not shown to the human. Fix these and ask again:",
          ...errors.map((m) => `- ${m}`),
          ...warnings.map((m) => `- ${m}`),
        ].join("\n");
        return { blocked: true, message, warnings: [] };
      }
      blocks.delete(sessionID);
      return { blocked: false, message: "", warnings: [...errors, ...warnings] };
    },
  };
}
