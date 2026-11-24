// Mechanical checks of the writing rules in the shared agent instructions.
// Plain JavaScript with no harness import, so any harness can load it.

const JAPANESE = String.raw`\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Han}ー`;
const SPACED = new RegExp(String.raw`[${JAPANESE}][ \u3000]+(?=[A-Za-z0-9])|[A-Za-z0-9][ \u3000]+(?=[${JAPANESE}])`, "gu");
// A token holding "/" counts as a URL or a path. Its class leaves out the
// backtick, brackets, parentheses, and angle brackets, so a path never
// swallows the start of a code span or a Markdown link.
const EXEMPT = /```[\s\S]*?(?:```|$)|`[^`\n]*`|\]\(<[^>\n]*>\)|\]\([^)\n]*\)|[!-'*-;=?-Z\\^_a-z{-~]*\/[!-'*-;=?-Z\\^_a-z{-~]*/g;
const ASIDE = /\([^()\n]*\)|（[^（）\n]*）/g;
// rm as a command word: at the start or after a separator, never `git rm` or `echo rm`.
// Its arguments end at a separator or at a # that starts a word, a shell comment.
const RM = /(?:^|[;&|\n(]\s*)rm\s+((?:[^;&|\n)#]|(?<=\S)#)*)/g;
const PARENT_SEGMENT = /(?:^|\/)\.\.(?:\/|["']?$)/;
const TEMPORARY = /^["']?(?:\/tmp\/|\/private\/tmp\/|\/private\/var\/folders\/|\/var\/folders\/|\$\{?TMPDIR\}?\/)/;

/** Replaces code and paths with filler of the same length, so indices still point into the original text. */
function maskExempt(text) {
	return text.replace(EXEMPT, (token) => "\0".repeat(token.length));
}

/** Japanese text with a space next to an alphanumeric, as `{ snippet }` items. */
export function spacingViolations(text) {
	return [...maskExempt(text).matchAll(SPACED)].map((match) => ({
		snippet: text.slice(match.index, match.index + match[0].length + 1),
	}));
}

/** Parenthetical asides in prose, as `{ snippet }` items. */
export function parentheticalAsides(text) {
	return [...maskExempt(text).matchAll(ASIDE)].map((match) => ({ snippet: match[0] }));
}

/** `rm` targets outside the temporary directories, as path strings. */
export function nonTemporaryRemovals(command) {
	return [...command.matchAll(RM)].flatMap((match) =>
		match[1]
			.trim()
			.split(/\s+/)
			.filter((word) => word && !word.startsWith("-") && (!TEMPORARY.test(word) || PARENT_SEGMENT.test(word))),
	);
}
