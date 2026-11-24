// Claude Code hook that applies the shared writing-rule checks.
// Usage: node hook.mjs stop | prompt | tool, with the hook event JSON on stdin.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { nonTemporaryRemovals, parentheticalAsides, spacingViolations } from "../rules.mjs";

const MAX_SEND_BACKS = 2;

function quote(items) {
	return items.map((item) => `「${item.snippet ?? item}」`).join("、");
}

// Each hook call is a separate process, so the send-back count and the
// pending aside warning live in a file per session.
function stateFile(sessionId) {
	const directory = join(tmpdir(), "agent-writing-rules-claude");
	mkdirSync(directory, { recursive: true });
	return join(directory, `${String(sessionId).replace(/[^\w-]/g, "_")}.json`);
}

function readState(file) {
	try {
		return { sendBacks: 0, asides: [], ...JSON.parse(readFileSync(file, "utf8")) };
	} catch {
		return { sendBacks: 0, asides: [] };
	}
}

function answer(event, additionalContext) {
	return { hookSpecificOutput: { hookEventName: event, additionalContext } };
}

const handlers = {
	stop(input) {
		const file = stateFile(input.session_id);
		const state = readState(file);
		const reply = input.last_assistant_message ?? "";
		state.asides = parentheticalAsides(reply).map((aside) => aside.snippet);
		const violations = spacingViolations(reply);
		if (violations.length === 0 || state.sendBacks >= MAX_SEND_BACKS) {
			writeFileSync(file, JSON.stringify(state));
			return undefined;
		}
		state.sendBacks += 1;
		writeFileSync(file, JSON.stringify(state));
		return {
			decision: "block",
			reason: `The reply puts a space between a Japanese character and an adjacent alphanumeric at ${quote(violations)}. Rewrite the whole reply without those spaces, outside code, URLs, and paths.`,
		};
	},

	// A human message opens a fresh allowance of send-backs and delivers the
	// aside warning once.
	prompt(input) {
		const file = stateFile(input.session_id);
		const { asides } = readState(file);
		writeFileSync(file, JSON.stringify({ sendBacks: 0, asides: [] }));
		if (asides.length === 0) return undefined;
		return answer(
			"UserPromptSubmit",
			`Your previous reply used parenthetical asides: ${quote(asides)}. Write such content as its own clause or sentence. This check can misjudge, so ignore it when the parentheses were not an aside.`,
		);
	},

	tool(input) {
		if (typeof input.tool_input?.command !== "string") return undefined;
		const targets = nonTemporaryRemovals(input.tool_input.command);
		if (targets.length === 0) return undefined;
		return answer(
			"PostToolUse",
			`rm deleted ${quote(targets)}, which is outside the temporary directories. Delete with trash instead, so a mistake can be undone from the Trash.`,
		);
	},
};

const output = handlers[process.argv[2]]?.(JSON.parse(readFileSync(0, "utf8")));
if (output) process.stdout.write(JSON.stringify(output));
