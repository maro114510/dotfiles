# OpenCode in CI

Lets the owner hand a small Issue to OpenCode in GitHub Actions and get a draft pull request back. The owner chooses the Issue, reviews, and merges, so CI saves the owner's time on small edits and decides nothing for them.

When goals conflict, keeping secrets and write access away from anyone but the owner comes before how many Issues a run can finish, and a simple workflow comes before using the quota fully.

Out of scope: starting work without the owner's comment, judging whether an Issue should be done, reviewing, and working on an existing pull request. The [issue-size](../.github/workflows/reusable-issue-size.yml) labels only help the owner choose.

## Two stages

A run is two jobs, so that no job holds both the model and a token that can write.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, and a read-only token | Runs OpenCode on the default branch's commit at the time of the comment, and hands over a patch and that commit |
| Publish | `GITHUB_TOKEN` with Contents and Pull requests write, and no outside secret | Applies the patch to that same commit, checks the result, pushes a new branch, and opens a draft pull request |

- Publish runs no model and no code from the patch, and treats the patch as untrusted.
- Publish opens the pull request as a draft itself, so the draft does not depend on the model.
- Publish names the branch from the Issue number and the run, and fails if the branch exists, so it never moves an existing branch.
- Publish writes the title and body itself from the Issue. The model's own summary goes only to the job summary, so it cannot close other Issues or mention anyone.
- Generate gets no cache access, as issue-size does.

### What Publish refuses

Publish checks the tree after applying the patch, not the patch text, because a patch can reach a path its text does not name. It lists every changed path, with renames split into their old and new paths, and refuses the whole patch when any of these holds:

- A path is under `.github/`.
- A file is a symbolic link or a submodule, or the change is binary.
- The patch contains text in the model key's format, `oc_sk_`.

Other files that act on checkout, such as `.gitattributes` or `.envrc`, are left to the owner's review.

A refusal does not keep the key secret: the patch was already stored as an artifact that anyone who can read the repository can download. A refusal for the key's format therefore means revoking the key. Artifacts are kept for one day.

## Repository settings

Each repository allows GitHub Actions to create and approve pull requests. Without it, `GITHUB_TOKEN` cannot open the pull request. The same setting lets the token approve one; maro114510/skills requires no approval, so this changes little.

## Who can start a run

| Event | Starts a run |
|---|---|
| A new comment on an Issue, not a pull request, whose body starts with `/oc`, by the repository owner, on an Issue that the owner or maronium[bot] opened | Yes |
| An edited comment, a comment by anyone else or by a bot, a comment on a pull request, a label, a schedule, or any other event | No |

The check runs in the job's condition, before any step can read a secret. The owner is whoever GitHub reports as `author_association` `OWNER`, not an account named in the comment.

## What the model reads

- The Issue's title and body, and the owner's comments on it, including the triggering one. Only the owner can change these, because the Issue's author is the owner or maronium[bot].
- No comment by anyone else, because a comment in a public repository can steer the model, and HTML comments that the page hides still reach it.
- The checkout of the default branch, with its instruction files.

A body that maronium[bot] wrote comes from a local agent, which may have read public content that steers it. That reaches the model too; this is accepted, and the owner reads the body before commenting.

## What the model may do

- Read and edit files in the checkout, and run shell commands, so it can run tests.
- OpenCode's own web fetch, web search, and access outside the checkout are denied, in a config the workflow writes before the run. Every permission is set to allow or deny, so nothing waits for an answer.
- A fixed time limit ends the job.
- It has no Git credentials: the checkout keeps none, and the job's token can only read.

The shell runs with the runner's full file, process, and network access, so the denials above stop only OpenCode's tools. The shell can read the model key and send it out, and outside content can still reach the model through it. That is accepted because of the budget below.

## Model, key, and quota

| Item | Decision | Why |
|---|---|---|
| Model | `opencode-go/deepseek-v4.1-flash` | The owner's OpenCode Go subscription |
| Data region | The workspace allows Global, the region this model needs | Accepted for every repository, public and private, to match the owner's local use |
| Key | A service account key in the owner's workspace, restricted to calling models, with an expiration | Usage is counted apart from the owner's own, and a leaked key can do nothing else |
| Budget | `$0` for that service account | A `$0` budget blocks spend paid from credits and leaves Go usage within the plan, so a leaked or repeated key stops when the Go allowance runs out |

- This needs the Go or Go Plus plan, which covers the workspace's API keys. Go Teams does not cover service accounts, so every request would fail under the `$0` budget.
- Runs are not queued or limited in number. Only the owner starts them, and each ends at the time limit.
- CI and the owner's local sessions share one Go allowance. Runs that use up the 5-hour window stop local work until it resets.
- The model's zero data retention depends on the provider's agreement, which OpenCode renews monthly.

## Merging

The checks on a pull request from `GITHUB_TOKEN` start only after a person with write access approves them in the merge box. The repository admin can still merge without them through GitHub's bypass prompt, so a draft merged without approval reaches `main` unchecked. This is accepted; the owner approves the checks when opening the draft.

## Layout

The behavior lives in reusable workflows in this repository. Each repository adds a small caller that holds the trigger, the permissions, and the author checks, as with issue-size. The OpenCode CLI is installed at a pinned version.

## Not yet checked

- That OpenCode reads the key from `OPENCODE_API_KEY` for the `opencode-go` provider.
- That Publish can open the pull request once the repository setting is on.
