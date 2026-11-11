/**
 * Guard: the major denials of the managed OpenCode config, for Pi.
 *
 * - read blocks secret files; committed env templates stay readable
 * - write and edit block .env files and anything under .ssh or .aws
 * - bash asks before a major destructive command, and blocks it without a UI
 *
 * Best effort, not a security boundary: see docs/pi-guard.md.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve, sep } from "node:path";

// Names are compared in lower case: the default macOS filesystem ignores case.
const SECRET_DIRS = [".ssh", ".aws"];
const UNREADABLE = [/^\.env/, /\.pem$/, /\.key$/, /id_rsa$/, /id_ed25519$/, /credentials\.json$/];
const READABLE = [/\.env\.(example|sample|template)$/];
const UNWRITABLE = [/^\.env/];

// Arguments up to the next ; & | or newline, so a pattern stays in one command.
const ARGS = String.raw`(?:[^;&|\n]*\s)?`;
const DESTRUCTIVE = [
	/\bsudo\b/,
	new RegExp(String.raw`\brm\s${ARGS}(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)\b`),
	new RegExp(String.raw`\bgit\s${ARGS}push\s${ARGS}(-[a-zA-Z]*[fd][a-zA-Z]*\b|--force|--delete\b|[+:]\S)`),
	new RegExp(String.raw`\bgit\s${ARGS}reset\s${ARGS}--hard\b`),
	new RegExp(String.raw`\bgh\s${ARGS}([a-z]+-)?delete\b`),
	new RegExp(String.raw`\bgh\s+api\s${ARGS}(-X\s*|--method[=\s]+)DELETE\b`, "i"),
];

// The path the tool will open, resolved against the working directory, plus
// its symlink target, so a link cannot rename a secret away. A file that does
// not exist yet takes the real path of its parent directory.
function forms(input: unknown, cwd: string): string[] {
	if (typeof input !== "string") return [];
	let path = input.replace(/^@/, "");
	if (path === "~" || path.startsWith("~/")) path = homedir() + path.slice(1);
	const absolute = resolve(cwd, path);
	try {
		return [absolute, realpathSync(absolute)];
	} catch {
		try {
			return [absolute, join(realpathSync(dirname(absolute)), basename(absolute))];
		} catch {
			return [absolute];
		}
	}
}

function isSecret(path: string, blocked: RegExp[], allowed: RegExp[]): boolean {
	const name = basename(path).toLowerCase();
	if (blocked.some((p) => p.test(name)) && !allowed.some((p) => p.test(name))) return true;
	return path.split(sep).slice(0, -1).some((dir) => SECRET_DIRS.includes(dir.toLowerCase()));
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		const input = event.input as { path?: unknown; command?: unknown };

		if (event.toolName === "read" || event.toolName === "write" || event.toolName === "edit") {
			const [blocked, allowed] = event.toolName === "read" ? [UNREADABLE, READABLE] : [UNWRITABLE, []];
			if (!forms(input.path, ctx.cwd).some((p) => isSecret(p, blocked, allowed))) return undefined;
			const reason = `guard: ${event.toolName} of ${String(input.path)} is blocked as a secret file`;
			if (ctx.hasUI) ctx.ui.notify(reason, "warning");
			return { block: true, reason };
		}

		if (event.toolName === "bash" && typeof input.command === "string") {
			const command = input.command;
			if (!DESTRUCTIVE.some((p) => p.test(command))) return undefined;
			if (!ctx.hasUI) return { block: true, reason: "guard: destructive command blocked, no UI to confirm" };
			if (!(await ctx.ui.confirm("guard: destructive command", `${command}\n\nRun it?`))) {
				return { block: true, reason: "guard: destructive command refused by the user" };
			}
		}

		return undefined;
	});
}
