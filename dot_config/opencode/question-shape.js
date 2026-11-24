// Checks the shape of the questions an agent asks the human. Plain data in and
// out, with no OpenCode import, so a Claude Code hook can reuse it.

// Returns the rule violations that send a question back to the agent, and the
// findings that may misjudge, so they only warn.
export function checkQuestions(questions) {
  return { errors: [], warnings: [] };
}

// Decides, per session, whether a question goes back to the agent or reaches
// the human.
export function createQuestionGate() {
  return {
    review(sessionID, questions) {
      return { blocked: false, message: "", warnings: [] };
    },
  };
}
