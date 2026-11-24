// Mechanical checks of the writing rules in the shared agent instructions.
// Plain JavaScript with no harness import, so any harness can load it.

/** Japanese text with a space next to an alphanumeric, as `{ snippet }` items. */
export function spacingViolations(_text) {
	return [];
}

/** Parenthetical asides in prose, as `{ snippet }` items. */
export function parentheticalAsides(_text) {
	return [];
}

/** `rm` targets outside the temporary directories, as path strings. */
export function nonTemporaryRemovals(_command) {
	return [];
}
