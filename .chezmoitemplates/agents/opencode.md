## Delegate

- `explore` for non-trivial local code investigation: multi-file searches, tracing call paths, understanding existing behavior or conventions.
- `general` for external research: upstream documentation, dependency or library source, cross-checking local code against upstream implementations.

## Do not delegate

- Design decisions and important conclusions.
- Implementation.
- Final verification.
- Trivial lookups: single-file reads, targeted searches, quick commands.

## Parallel Pull Requests

- Do not open a pull request that changes a file another open pull request already changes; wait until that one merges.
- Merge pull requests in dependency order, and name the one that must merge first in the pull request body.
