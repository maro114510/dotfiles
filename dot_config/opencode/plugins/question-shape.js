// Sends a question tool call back to the agent when its shape breaks a rule in
// ../question-shape.js, and adds the warnings to the result of one that is shown.
import { createQuestionGate } from "../question-shape.js";

const QUESTION_TOOL = "question";

export default {
  id: "dotfiles.question-shape",
  async setup(api) {
    const gate = createQuestionGate();
    const pending = new Map();
    const hooks = await Promise.all([
      // A throw here fails the tool call with its message, which is what the
      // agent reads, before OpenCode shows anything to the human.
      api.tool.hook("execute.before", (call) => {
        if (call.tool !== QUESTION_TOOL) return;
        const questions = Array.isArray(call.input?.questions) ? call.input.questions : [];
        const review = gate.review(call.sessionID, questions);
        if (review.blocked) throw new Error(review.message);
        if (review.warnings.length > 0) pending.set(call.id, review.warnings);
      }),
      api.tool.hook("execute.after", (call) => {
        const warnings = pending.get(call.id);
        if (!warnings) return;
        pending.delete(call.id);
        if (call.status !== "completed") return;
        const text = ["Warnings about how the question was asked:", ...warnings.map((m) => `- ${m}`)].join("\n");
        const content = call.result.content;
        call.result = {
          ...call.result,
          content: Array.isArray(content) ? [...content, { type: "text", text }] : `${content ?? ""}\n\n${text}`,
        };
      }),
    ]);
    return () => Promise.all(hooks.map((hook) => hook.dispose()));
  },
};
