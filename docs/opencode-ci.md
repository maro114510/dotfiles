# OpenCode in CI

Lets the owner hand a small Issue to OpenCode, which runs in GitHub Actions and opens a draft pull request. The owner decides what to hand over and merges by hand, so CI saves the owner's own time on small edits without deciding anything for them.

Starting work on its own, judging whether an Issue should be done, and reviewing are out of scope. The [issue-size](../.github/workflows/reusable-issue-size.yml) labels only help the owner choose.

## Who can start a run

| Event | Starts a run |
|---|---|
| A comment that mentions `/oc` or `/opencode`, by an account with write access to the repository | Yes |
| An Issue opened or edited, a label added, a schedule, or any other event | No |

The action checks write access itself; the workflow does not trust the comment text for it.

A run reads the whole Issue thread, including comments by people without write access. In a public repository the owner reads the thread before mentioning `/oc`, because a comment there can steer the model.

## What a run may change

- It works on a new branch and opens a pull request against the default branch.
- The pull request is a draft. The prompt tells OpenCode to create its own branch and open the pull request as a draft, because the action itself opens a ready one when the model leaves the branch to it.
- Marking it ready, approving, and merging stay with the owner.

## Identity and credentials

| Credential | Source | Why |
|---|---|---|
| GitHub token | The OpenCode GitHub App, exchanged through the job's OIDC token | Pull requests from `GITHUB_TOKEN` start no workflows, so the required checks never run. The App also needs no key stored in each repository |
| Model key | The `OPENCODE_GO_API_KEY` secret, for OpenCode Go | The run uses the owner's subscription |

Runs act as the OpenCode App, not as maronium. Records keep telling the owner's agents apart from CI.

## Model and quota

- The model is `opencode-go/deepseek-v4.1-flash`.
- OpenCode Go's quota is shared with the owner's local sessions, so a burst of runs can stop local work until the window resets.

## Session sharing

The action shares the session publicly by default in a public repository. Every caller sets sharing off, because the session holds the Issue and the repository's contents and its link would sit on the pull request.

## Layout

The behavior lives in one reusable workflow in this repository. Each repository adds a small caller that declares only the trigger and the permissions, as with issue-size. The first repository is maro114510/skills, after a check in a private sandbox repository; the rest follow.

## Risks

- If the model ignores the draft instruction, the action opens a ready pull request, and review automation for ready pull requests starts.
- The OpenCode App holds write access to every repository it is installed on. Whether that includes workflow files has not been checked.
- When OpenCode opens the pull request itself, the action skips its own push and pull request. Whether the model can reach the App token for that has not been checked.
- Whether the action runs with an OpenCode Go key has not been checked yet.
