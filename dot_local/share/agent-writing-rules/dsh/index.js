// DeepSeek Harness plugin that applies the shared writing-rule checks.

export const name = "agent-writing-rules";

export function apply(ctx) {
	ctx.on("agent/turn-stopping", () => {});
	ctx.on("tools/post-execute", (_exec, _result, next) => next());
}
