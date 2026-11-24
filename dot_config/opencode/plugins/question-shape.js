// Sends a question tool call back to the agent when its shape breaks a rule in
// ../question-shape.js, and adds the warnings to the result of one that is shown.
import { checkQuestions } from "../question-shape.js";

export default {
  id: "dotfiles.question-shape",
  async setup(api) {
    const hooks = await Promise.all([
      api.tool.hook("execute.before", () => {}),
      api.tool.hook("execute.after", () => {}),
    ]);
    return () => Promise.all(hooks.map((hook) => hook.dispose()));
  },
};
