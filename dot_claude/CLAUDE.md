## Working Principles

Keep changes minimal and maintain backward compatibility.

## Worktree Workflow

- All work must be done on a worktree using [git-wt](https://github.com/k1LoW/git-wt)
- Direct changes to the main branch are prohibited — always work on a worktree and merge after review

## Scope of This File

- This file applies to all projects, so only generic rules belong here
- Project-specific rules go in each project's `CLAUDE.md` or `.claude/rules/`
- Avoid duplicating or contradicting rules between this file and project-level CLAUDE.md

## Clarify Before Implementing

Surface assumptions before writing code, not after.

- If multiple interpretations exist, list them and ask — don't silently pick one.
- If a simpler approach exists, say so before starting.
- Ask once with all your questions grouped. Don't interrupt repeatedly mid-task.
- If something is still unclear after asking, name the ambiguity explicitly in your response.

## Simplicity First

Solve the stated problem. Nothing more.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "future-proofing" that wasn't requested.
- If you've written significantly more code than the task warrants, reconsider the approach.

## Surgical Changes

Touch only what the task requires.

- Don't improve adjacent code, comments, or formatting — even if they're suboptimal.
- Consistency with surrounding code takes priority over your stylistic preferences. The codebase has a voice; match it.
- If you notice unrelated issues, mention them — don't silently fix them.
- Remove only the imports/variables/functions that YOUR changes made unused. Leave pre-existing dead code alone.

## Define Done Before Starting

For any non-trivial task, make the exit condition explicit before writing code.

**For testable work, follow t-wada's TDD cycle:**
1. Write a test list — all the cases you can think of, before writing any code
2. Pick one case: write a failing test that specifies the behavior (Red)
3. Write the minimum code to make it pass — no more (Green)
4. Refactor while keeping tests green (Refactor)
5. Repeat until the test list is exhausted

Tests are specifications, not afterthoughts. If the test is hard to write, the design is wrong.

**For non-testable tasks (config, UI, scripts):**
Define the observable change that confirms success before starting:
- "The server returns 404 for unknown routes"
- "The button is disabled when the form is empty"

Don't mark a task complete until the exit condition is verified.
