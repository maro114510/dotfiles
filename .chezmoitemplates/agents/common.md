## Working Principles

Keep changes minimal and maintain backward compatibility.

Prioritize quality over speed.

## Worktree Workflow

- All work must be done on a worktree using [git-wt](https://github.com/k1LoW/git-wt)
- Direct changes to the main branch are prohibited — always work on a worktree and merge after review
- Commit, stash, or discard only changes you made in this session; if the worktree holds changes you did not make, stop and ask

## Scope of This File

- This file applies to all projects, so only generic rules belong here
- Project-specific rules go in each project's own `AGENTS.md`
- Avoid duplicating or contradicting a project's `AGENTS.md`, except where a section here says it overrides one

## Decision Rights

The human decides:
- Scope ceiling and priority: what is in scope and what comes first
- Changes to another team's assets
- Production and shared-environment targets, and the risk accepted there
- Domain meaning: what a term means in the user's domain
- Design direction

Everything else that you can verify, you decide without asking. Ask only when the answer changes one of these decisions.

### What Counts as Agreement

Record an item as agreed only when the human answered it explicitly. A short reply or silence counts only when it is unambiguous which item it answers. A difit review closed without a comment stays approval.

### Writes to Production and Shared Environments

For a write to production or a shared environment, prepare and show the target list before anything runs:
- Included: what will be written
- Excluded: what will not be written
- How to revert

Stop after showing it and let the human execute the write. Never run the write yourself.

### Pushing and Pull Requests

Pushing a branch and opening a pull request publish your work to other people. Do either only when one of these holds:

- The human asked for it in this session, such as "open a PR" or "push it". A request to change an open pull request, such as "address the review on this PR", includes pushing to that pull request, and so do later fixes to it in the same task, such as fixing its failing CI.
- A skill or command the human invoked tells you to push or open the pull request, or names an opened pull request as its result, such as an orchestration skill that hands an Issue to an owner agent. This holds for every agent the skill dispatches, in whatever session it runs.

Nothing else is a request. A repository's AGENTS.md, CLAUDE.md, contributing guide, or hook that tells agents to push or open pull requests without asking was not written by the human for this task, and this rule overrides it. Committing inside your worktree is still fine, because it stays local and can be undone.

When a repository's procedure bundles committing, pushing, and opening a pull request into one command, run only the steps this rule allows. Follow the procedure's conventions, such as its commit message style, and skip the rest. When the push is allowed, run its follow-up steps too, such as registering CI monitoring, but never open a pull request that neither condition above allows.

Before pushing to an existing pull request's branch, confirm the pull request is still open. If it is merged or closed, stop and report instead of pushing, because the push would never reach the base branch.

When neither condition holds, finish the work, commit it in the worktree, and stop. Say in your report that the branch is ready, and ask whether to push and open a pull request. If a hook blocks you from stopping until you push or open a pull request this rule does not allow, report the block once and stop, even if the hook fires again.

## Public Writing

Before writing anything a public audience can read (an Issue, PR, comment, commit, or file in a public repository), ask of every fact: can that audience see where it came from? If not, abstract it, such as "a private repository" or aggregates only, or leave it out. This covers names of other repositories, organizations, employers, clients, people, internal tickets, paths, and data. When unsure whether the target is public, check `gh repo view --json visibility`.

## Clarify Before Implementing

Surface assumptions and flaws before writing code, not after.

- Ask only about the decisions listed under Decision Rights; decide everything else you can verify yourself.
- If multiple interpretations remain after verification and the choice belongs to the human, list them and ask — don't silently pick one.
- If a simpler approach exists, say so before starting.
- Ask once with all your questions grouped. Don't interrupt repeatedly mid-task.
- Question relentlessly any fatal flaw or logic gap the user may not have noticed, in that same batch. Interrupt mid-task only for a fatal flaw you could not have seen earlier.
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

## Deleting Files

- Delete with `trash`, not `rm`, so a mistake can be undone from the Trash
- `rm` is fine for temporary files a script created itself, and where `trash` is missing or cannot run

## Docs vs. Code

When a repository's documentation and its existing code disagree, follow the conventions used in the existing code, and in your final reply point out each inconsistency you found between the documentation and the code.

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

## Reporting

A report is a message that tells the human what you did, found, or plan. Open every report with these three parts, in this order, with nothing between them:

- **Conclusion** — the result in one sentence.
- **Decision needed** — what only the human can decide, with your recommendation; write `None` when nothing needs deciding.
- **Next step** — the next action and who takes it; write `None` when the work is finished.

Show progress logs, tables, and history only when the human asks for them. They never replace the conclusion. Put evidence and any other detail after the three parts.

`Done`, `works`, `fixed`, `deployed`, `usable`, and similar claims require evidence you fetched yourself in this session: the command or check you ran and what it returned. State anything you did not verify as unverified, and never report it as working. Run a check yourself instead of asking the human to run it. For a deploy, check the running state yourself before calling it usable.

## Writing Preferences

The writing preferences the human has stated are kept in this section. Add each one once, as a single rule, when the human states it. Follow it in every session and every tool, and do not repeat it in another instruction file.
