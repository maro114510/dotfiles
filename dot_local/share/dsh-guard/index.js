/**
 * Guard: the major denials of the managed OpenCode config and Pi guard, for DSH.
 *
 * - file tools refuse secret files, and refuse writes to .env files, anything
 *   under .ssh or .aws, and the global DSH, OpenCode, and Pi config and plugins
 * - bash refuses sudo, git reset --hard, a force or deleting push, gh delete,
 *   gh api DELETE, and a recursive rm outside temporary directories and the
 *   repository's worktrees
 *
 * Every rule is a refusal, never a question: the shared policy sets approval
 * "never", so DSH would reject a question unanswered. A guard added with
 * ctx.tools.guard() is evaluated after every tools/pre-execute listener, and a
 * call made through run_code reaches it as a nested call, so both paths pass.
 *
 * Best effort, not a security boundary: see docs/dsh-guard.md.
 */

import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join, resolve, sep } from "node:path";

export const name = "dsh-guard";
export const inject = ["tools"];

// The path tables below hold every entry of dot_pi/agent/extensions/guard.ts plus the DSH ones; a test keeps that true.
// Names are compared in lower case: the default macOS filesystem ignores case.
const SECRET_DIRS = [".ssh", ".aws"];
const UNREADABLE = [/^\.env/, /\.pem$/, /\.key$/, /id_rsa$/, /id_ed25519$/, /credentials\.json$/];
const READABLE = [/\.env\.(example|sample|template)$/];
const UNWRITABLE = [/^\.env/];

// A path ending in any directory; one ending in "/" covers everything under it.
const UNREADABLE_PATHS = [
	".config/opencode/service.json",
	".local/share/opencode/auth.json",
	".dsh/.credentials.yaml",
	".dsh/plugins/subscriptions/auth.json",
];
const UNWRITABLE_PATHS = [
	".config/opencode/opencode.json",
	".config/opencode/opencode.jsonc",
	".config/opencode/plugin/",
	".config/opencode/plugins/",
	".pi/agent/settings.json",
	".pi/agent/extensions/",
	".dsh/AGENTS.md",
	".dsh/cordis.patch.yml",
	".dsh/web-launch.conf",
	".dsh/profiles/",
	".dsh/plugins/",
	".config/dsh/",
	".local/share/dsh-guard/",
];

// Keys that carry a file path in the arguments of the built-in and dsh-ops tools.
const PATH_KEYS = new Set([
	"path", "file_path", "filePath", "notebook_path", "paths", "files", "file",
	"from", "to", "source", "destination", "target", "root", "directory",
]);
const WRITE_TOOL = /(^|_)(write|edit|replace|remove|delete|mkdir|patch)(_|$)|^str_replace_editor$/;
const TRANSFER_TOOL = /(^|_)(copy|move|batch)(_|$)/;
const SHELL_TOOL = /^(ops_)?bash$/;
const SHELLS = new Set(["sh", "bash", "zsh", "dash", "ksh"]);
// Commands that run what follows them, so the guard looks past them.
const WRAPPERS = new Set(["env", "command", "builtin", "exec", "time", "nohup", "xargs", "then", "do", "else", "!"]);

// The path the tool will open, resolved against the working directory, plus
// its symlink target, so a link cannot rename a secret away. A file that does
// not exist yet takes the real path of its parent directory.
function forms(input, cwd) {
	if (typeof input !== "string" || input === "") return [];
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

// Unlike the Pi guard, the last component counts too, so a search rooted at ~/.ssh is refused.
function isSecret(path, blocked, allowed) {
	const name = basename(path).toLowerCase();
	if (blocked.some((p) => p.test(name)) && !allowed.some((p) => p.test(name))) return true;
	return path.split(sep).some((dir) => SECRET_DIRS.includes(dir.toLowerCase()));
}

function isProtected(path, protectedPaths) {
	const lower = path.toLowerCase();
	return protectedPaths.some((p) => {
		const entry = p.toLowerCase();
		return entry.endsWith("/") ? lower.includes(`/${entry}`) : lower.endsWith(`/${entry}`);
	});
}

const unreadable = (path) => isSecret(path, UNREADABLE, READABLE) || isProtected(path, UNREADABLE_PATHS);
const unwritable = (path) => isSecret(path, UNWRITABLE, []) || isProtected(path, UNWRITABLE_PATHS);

// Every string under a path key, at any depth of the arguments.
function pathArguments(value, key = "", depth = 0, found = []) {
	if (depth > 6) return found;
	if (typeof value === "string") {
		if (PATH_KEYS.has(key)) found.push(value);
	} else if (Array.isArray(value)) {
		for (const item of value) pathArguments(item, key, depth + 1, found);
	} else if (value !== null && typeof value === "object") {
		for (const [k, v] of Object.entries(value)) pathArguments(v, k, depth + 1, found);
	}
	return found;
}

// The files an apply_patch input adds, updates, deletes, or moves to.
function patchPaths(input) {
	if (typeof input !== "string") return [];
	return [...input.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)].map((m) => m[1].trim());
}

function fileReason(tool, args, cwd) {
	const mode = fileMode(tool, args);
	const paths = tool === "apply_patch" ? patchPaths(args?.input) : pathArguments(args);
	const checks = mode === "read" ? [unreadable] : mode === "write" ? [unwritable] : [unreadable, unwritable];
	for (const path of paths) {
		if (!forms(path, cwd).some((form) => checks.some((check) => check(form)))) continue;
		return mode === "read"
			? `guard: ${tool} of ${path} is refused as a secret or protected file. Ask the user for the value you need, or read a template such as .env.example.`
			: `guard: ${tool} of ${path} is refused as a secret location or agent configuration. Ask the user to make the change, or edit its source in the dotfiles repository.`;
	}
	return undefined;
}

function fileMode(tool, args) {
	if (tool === "str_replace_editor") return args?.command === "view" ? "read" : "write";
	if (TRANSFER_TOOL.test(tool)) return "both";
	return WRITE_TOOL.test(tool) ? "write" : "read";
}

// Words of each simple command, with quotes and redirections resolved and the
// bodies of heredocs that feed a shell kept for a second look.
function tokenize(text) {
	const segments = [[]];
	const pending = [];
	const bodies = [];
	let word = null;
	let drop = false;
	let i = 0;
	const flush = () => {
		if (word !== null && !drop) segments.at(-1).push(word);
		if (word !== null) drop = false;
		word = null;
	};
	const split = () => {
		flush();
		if (segments.at(-1).length > 0) segments.push([]);
	};
	const add = (text) => {
		word = (word ?? "") + text;
	};
	while (i < text.length) {
		const c = text[i];
		if (c === "'") {
			const end = text.indexOf("'", i + 1);
			const stop = end < 0 ? text.length : end;
			add(text.slice(i + 1, stop));
			i = stop + 1;
		} else if (c === '"') {
			i++;
			word ??= "";
			while (i < text.length && text[i] !== '"') {
				if (text[i] === "\\" && '"\\$`'.includes(text[i + 1] ?? "")) i++;
				add(text[i]);
				i++;
			}
			i++;
		} else if (c === "\\") {
			if (text[i + 1] !== "\n") add(text[i + 1] ?? "");
			i += 2;
		} else if (c === " " || c === "\t" || c === "\r") {
			flush();
			i++;
		} else if (c === "<" && text[i + 1] === "<" && text[i + 2] !== "<") {
			let j = i + 2;
			const strip = text[j] === "-";
			if (strip) j++;
			while (text[j] === " " || text[j] === "\t") j++;
			let delimiter = "";
			while (j < text.length && !/[\s;&|<>()]/.test(text[j])) {
				if (text[j] !== "'" && text[j] !== '"' && text[j] !== "\\") delimiter += text[j];
				j++;
			}
			pending.push({ delimiter, strip, owner: segments.length - 1 });
			i = j;
		} else if (c === "<" || c === ">" || (c === "&" && text[i + 1] === ">")) {
			if (word !== null && /^\d+$/.test(word)) word = null;
			flush();
			while (i < text.length && /[<>&|]/.test(text[i])) i++;
			drop = true;
		} else if (c === "\n") {
			split();
			i++;
			for (const { delimiter, strip, owner } of pending.splice(0)) {
				const start = i;
				let end = text.length;
				let next = text.length;
				for (let at = i; at < text.length; ) {
					const eol = text.indexOf("\n", at);
					const stop = eol < 0 ? text.length : eol;
					const line = text.slice(at, stop);
					if ((strip ? line.replace(/^\t+/, "") : line) === delimiter) {
						end = at;
						next = Math.min(stop + 1, text.length);
						break;
					}
					at = stop + 1;
				}
				i = next;
				const first = segments[owner]?.[0];
				if (first !== undefined && SHELLS.has(basename(first))) bodies.push(text.slice(start, end));
			}
		} else if (c === ";" || c === "|" || c === "&" || c === "(" || c === ")" || c === "`") {
			split();
			i++;
		} else {
			add(c);
			i++;
		}
	}
	flush();
	return { segments: segments.filter((words) => words.length > 0), bodies };
}

// The command a segment runs, after assignments and wrappers.
function commandOf(words) {
	let viaXargs = false;
	let i = 0;
	for (;;) {
		while (i < words.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i])) i++;
		if (i >= words.length) return undefined;
		const name = basename(words[i]);
		if (!WRAPPERS.has(name)) return { name, args: words.slice(i + 1), viaXargs };
		if (name === "xargs") viaXargs = true;
		i++;
		while (i < words.length && words[i].startsWith("-")) i++;
	}
}

function realOrSelf(path) {
	try {
		return realpathSync(path);
	} catch {
		return path;
	}
}

function temporaryRoots() {
	const roots = ["/tmp", "/var/tmp", "/var/folders", tmpdir(), process.env.TMPDIR].filter(Boolean);
	return [...new Set(roots.flatMap((root) => [resolve(root), realOrSelf(resolve(root))]))];
}

// The paths of every worktree of the repository that cwd belongs to, the main one first.
function worktreeRoots(cwd) {
	try {
		const out = execFileSync("git", ["-C", cwd, "worktree", "list", "--porcelain"], {
			encoding: "utf8",
			timeout: 3000,
			stdio: ["ignore", "pipe", "ignore"],
		});
		return out.split("\n").filter((line) => line.startsWith("worktree ")).map((line) => realOrSelf(line.slice(9)));
	} catch {
		return [];
	}
}

const strictlyInside = (path, root) => path !== root && path.startsWith(root + sep);

// Inside a temporary directory, or inside a worktree without touching its .git,
// another worktree, or a directory that holds one.
function removable(target, cwd) {
	let path = target.replace(/^\$\{?TMPDIR\}?(?=\/|$)/, process.env.TMPDIR || tmpdir());
	if (/[$`]/.test(path) || (path.startsWith("~") && path !== "~" && !path.startsWith("~/"))) return false;
	if (cwd === undefined && !/^[/~]/.test(path)) return false;
	const real = forms(path, cwd ?? "/").at(-1);
	if (real === undefined) return false;
	if (temporaryRoots().some((root) => strictlyInside(real, root))) return true;
	const roots = worktreeRoots(cwd ?? "/");
	return roots.some((root) => {
		if (!strictlyInside(real, root)) return false;
		if (real.slice(root.length + 1).split(sep).includes(".git")) return false;
		return !roots.some((other) => other !== root && (other === real || strictlyInside(other, real)));
	});
}

const refusals = {
	sudo: "guard: sudo is refused. Run the command without elevated privileges, or ask the user to run it.",
	reset: "guard: git reset --hard is refused. Use git stash to keep the changes, git restore <path> for one file, or git switch to change branches.",
	force: "guard: a force push is refused. Use git push --force-with-lease, which fails when the remote moved.",
	deletePush: "guard: deleting a remote branch or tag is refused. Ask the user to delete it.",
	gh: "guard: gh delete is refused. Ask the user to delete it, or close or archive it when that is enough.",
	api: "guard: gh api with DELETE is refused. Ask the user to make the call.",
};

function checkRm(args, cwd, viaXargs) {
	let recursive = false;
	let options = true;
	const targets = [];
	for (const arg of args) {
		if (options && arg === "--") options = false;
		else if (options && arg.startsWith("-")) recursive ||= arg === "--recursive" || /^-[a-zA-Z]*[rR]/.test(arg);
		else targets.push(arg);
	}
	if (!recursive) return undefined;
	if (viaXargs && targets.length === 0) return "guard: a recursive rm fed by xargs is refused. Name its targets inside a temporary directory or a worktree, or move them with trash.";
	const outside = targets.find((target) => !removable(target, cwd));
	if (outside === undefined) return undefined;
	return `guard: rm -r of ${outside} is refused, because it is outside temporary directories and the repository's worktrees. Move it with trash, or ask the user to remove it.`;
}

function checkGit(args) {
	let i = 0;
	while (i < args.length && args[i].startsWith("-")) i += ["-C", "-c", "--git-dir", "--work-tree", "--namespace"].includes(args[i]) ? 2 : 1;
	const rest = args.slice(i + 1);
	if (args[i] === "reset" && rest.includes("--hard")) return refusals.reset;
	if (args[i] !== "push") return undefined;
	for (const arg of rest) {
		if (arg === "--delete" || /^-[a-zA-Z]*d/.test(arg) || arg.startsWith(":")) return refusals.deletePush;
		if (arg === "--force" || /^-[a-zA-Z]*f/.test(arg) || arg.startsWith("+")) return refusals.force;
	}
	return undefined;
}

function checkGh(args) {
	if (args.some((arg) => /^([a-z]+-)?delete$/.test(arg))) return refusals.gh;
	if (args.find((arg) => !arg.startsWith("-")) !== "api") return undefined;
	for (let i = 0; i < args.length; i++) {
		const method = /^-X(.+)$/.exec(args[i])?.[1] ?? /^--method=(.+)$/.exec(args[i])?.[1]
			?? (args[i] === "-X" || args[i] === "--method" ? args[i + 1] : undefined);
		if (method?.toUpperCase() === "DELETE") return refusals.api;
	}
	return undefined;
}

function shellReason(command, cwd, depth = 0) {
	if (depth > 3) return undefined;
	const { segments, bodies } = tokenize(command);
	// A cd moves the directory that later relative rm targets live in; an unreadable one leaves it unknown.
	let dir = cwd;
	for (const words of segments) {
		const found = commandOf(words);
		if (found === undefined) continue;
		const { name, args, viaXargs } = found;
		let reason;
		if (name === "cd") {
			const to = args.find((arg) => !arg.startsWith("-"));
			dir = to === undefined || to.startsWith("~") || /[$`]/.test(to) ? undefined : dir && resolve(dir, to);
		} else if (name === "sudo") reason = refusals.sudo;
		else if (name === "rm") reason = checkRm(args, dir, viaXargs);
		else if (name === "git") reason = checkGit(args);
		else if (name === "gh") reason = checkGh(args);
		else if (name === "eval") reason = shellReason(args.join(" "), cwd, depth + 1);
		else if (SHELLS.has(name)) {
			const flag = args.findIndex((arg) => /^-[a-zA-Z]*c[a-zA-Z]*$/.test(arg));
			if (flag >= 0 && args[flag + 1] !== undefined) reason = shellReason(args[flag + 1], cwd, depth + 1);
		}
		if (reason !== undefined) return reason;
	}
	for (const body of bodies) {
		const reason = shellReason(body, cwd, depth + 1);
		if (reason !== undefined) return reason;
	}
	return undefined;
}

function sessionCwd(ctx, exec) {
	try {
		if (exec.agent !== undefined) return ctx.workingDirectory.get(exec.agent.session);
	} catch {
		// The service is not mounted in this profile.
	}
	return process.cwd();
}

export function decide(exec, cwd) {
	const args = exec.arguments;
	if (SHELL_TOOL.test(exec.name)) {
		if (typeof args?.command !== "string") return undefined;
		const workdir = typeof args.workdir === "string" && args.workdir !== "" ? resolve(cwd, args.workdir) : cwd;
		return shellReason(args.command, workdir);
	}
	return fileReason(exec.name, args, cwd);
}

export function apply(ctx) {
	ctx.effect(() => ctx.tools.guard((exec) => decide(exec, sessionCwd(ctx, exec))));
}
