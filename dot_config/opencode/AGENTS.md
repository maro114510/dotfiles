# Global Rules for OpenCode

## Delegate

- `explore` for non-trivial local code investigation: multi-file searches, tracing call paths, understanding existing behavior or conventions.
- `scout` for external research: upstream documentation, dependency or library source, cross-checking local code against upstream implementations.

## Do not delegate

- Design decisions and important conclusions.
- Implementation.
- Final verification.
- Trivial lookups: single-file reads, targeted searches, quick commands.

## Docs vs. Code

When a repository's documentation and its existing code disagree, follow the conventions used in the existing code, and in your final reply point out each inconsistency you found between the documentation and the code.
