// DeepSeek Harness plugin that applies the shared writing-rule checks.

import { randomUUID } from "node:crypto";
import { nonTemporaryRemovals, parentheticalAsides, spacingViolations } from "../rules.mjs";

export const name = "agent-writing-rules";

const SOURCE_KIND = "agent-writing-rules";
const MAX_SEND_BACKS = 2;

function message(summary, text) {
	return Object.freeze({
		id: randomUUID(),
		role: "user",
		content: [{ type: "text", text }],
		source: { kind: SOURCE_KIND, form: "notice", summary },
	});
}

function textOf(content) {
	return content.filter((block) => block.type === "text").map((block) => block.text).join("\n");
}

function quote(items) {
	return items.map((item) => `「${item.snippet ?? item}」`).join("、");
}

// The count and the last reply are read from the session log, not kept in
// memory, so a resumed or forked session counts the same way.
function sinceLastHumanMessage(agent) {
	const events = agent.session.snapshotEvents();
	let reply;
	let sendBacks = 0;
	for (let i = events.length - 1; i >= 0; i -= 1) {
		const { type, data } = events[i];
		if (type === "assistant/message") reply ??= textOf(data.message.content);
		if (type !== "user/message") continue;
		if (data.source?.kind === "user") break;
		if (data.source?.kind === SOURCE_KIND && data.source.summary === "spacing") sendBacks += 1;
	}
	return { reply, sendBacks };
}

export function apply(ctx) {
	ctx.on("agent/turn-stopping", ({ agent }) => {
		const { reply, sendBacks } = sinceLastHumanMessage(agent);
		if (reply === undefined || sendBacks >= MAX_SEND_BACKS) return;
		const violations = spacingViolations(reply);
		if (violations.length === 0) return;
		agent.steer(
			message(
				"spacing",
				`The reply puts a space between a Japanese character and an adjacent alphanumeric at ${quote(violations)}. Rewrite the whole reply without those spaces, outside code, URLs, and paths.`,
			),
		);
	});

	ctx.on("agent/pre-step", async (proposal, next) => {
		const decision = await next();
		if (decision.kind !== "enter" || !proposal.messages.some((m) => m.source.kind === "user")) return decision;
		const { reply } = sinceLastHumanMessage(proposal.agent);
		const asides = reply === undefined ? [] : parentheticalAsides(reply);
		if (asides.length === 0) return decision;
		const warning = message(
			"aside",
			`Your previous reply used parenthetical asides: ${quote(asides)}. Write such content as its own clause or sentence. This check can misjudge, so ignore it when the parentheses were not an aside.`,
		);
		return { ...decision, messages: [warning, ...decision.messages] };
	});

	ctx.on("tools/post-execute", async (exec, _result, next) => {
		const decision = await next();
		if (exec.name !== "bash" || decision.kind !== "accept" || typeof exec.arguments?.command !== "string") return decision;
		const targets = nonTemporaryRemovals(exec.arguments.command);
		if (targets.length === 0) return decision;
		const warning = message(
			"rm",
			`rm deleted ${quote(targets)}, which is outside the temporary directories. Delete with trash instead, so a mistake can be undone from the Trash.`,
		);
		return { ...decision, additionalContexts: [warning, ...(decision.additionalContexts ?? [])] };
	});
}
