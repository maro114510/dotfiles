# OpenCode in CI

Lets the owner hand a small Issue to OpenCode in GitHub Actions and get a draft pull request back. The owner chooses the Issue, reviews, and merges, so CI saves the owner's time on small edits and decides nothing for them.

When goals conflict, keeping secrets and write access away from anyone but the owner comes before how many Issues a run can finish.

Out of scope: starting work without the owner's comment, judging whether an Issue should be done, reviewing, and working on an existing pull request. The [issue-size](../.github/workflows/reusable-issue-size.yml) labels only help the owner choose.

## Two stages

A run is two jobs, so that no job holds both the model and a token that can write.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, and a read-only token | Runs OpenCode on a checkout of the default branch and hands over a patch and a summary |
| Publish | `GITHUB_TOKEN` with Contents and Pull requests write, and no outside secret | Checks the patch, pushes it to a new branch, and opens a draft pull request |

- Publish runs no model and no code from the patch. It treats the patch and the summary as untrusted.
- Publish refuses a patch that touches `.github/` or contains text in the model key's format, `oc_sk_`. The key-format check misses an encoded key; the budget below bounds that loss.
- Publish opens the pull request as a draft itself, so the draft does not depend on the model.
- Generate gets no cache access. A run starts from an owner's comment on the default branch, and a cache it wrote there would be read by every other workflow in the repository.
- A pull request from `GITHUB_TOKEN` starts its checks only after a person with write access approves them in the merge box. The owner approves when opening the draft; this is accepted in exchange for keeping the token to one repository and one run.

## Who can start a run

| Event | Starts a run |
|---|---|
| A new comment on an Issue, not a pull request, whose body starts with `/oc`, by the repository owner, on an Issue that the owner or maronium[bot] opened | Yes |
| An edited comment, a comment by anyone else or by a bot, a comment on a pull request, a label, a schedule, or any other event | No |

The check runs in the job's condition, before any step can read a secret. The owner is the repository's owner as GitHub reports it, `author_association` `OWNER`, not an account named in the comment.

## What the model reads

- The Issue's title and body, and the owner's comments on it, including the triggering one.
- No comment by anyone else, because a comment in a public repository can steer the model, and HTML comments the owner cannot see on the page still reach it.
- The repository's default branch as checked out, with its instruction files.

## What the model may do

- Read and edit files in the checkout, and run shell commands, so it can run tests.
- No web fetch and no access outside the checkout.
- A fixed time limit ends the job.
- It has no Git credentials: the checkout keeps none, and the job's token can only read.

The shell can read the model key from the environment and send it out. That loss is accepted because of the budget below, and the key is revoked and replaced when it is suspected.

## Model, key, and quota

| Item | Decision | Why |
|---|---|---|
| Model | `opencode-go/deepseek-v4.1-flash` | The owner's OpenCode Go subscription |
| Data region | The workspace allows Global, the region this model needs | Accepted for every repository, public and private, to match the owner's local use |
| Key | A service account key in the owner's workspace, restricted to calling models, with an expiration | Usage is counted apart from the owner's own, and a leaked key can do nothing else |
| Budget | `$0` for that service account | A `$0` budget blocks spend paid from credits and leaves Go usage within the plan, so a leaked or looping key stops when the Go allowance runs out |
| Concurrency | One run per repository at a time | Two comments cannot spend the allowance twice at once |

CI and the owner's local sessions share one Go allowance. Runs that use up the 5-hour window stop local work until it resets; only the owner can start runs, so this happens only when the owner starts many.

## Layout

The behavior lives in reusable workflows in this repository. Each repository adds a small caller that holds the trigger, the permissions, and the author checks, as with issue-size. The OpenCode CLI is installed at a pinned version.

## Not yet checked

- That a service account key in a workspace on the Go plan draws from the Go allowance.
- That OpenCode reads the key from `OPENCODE_API_KEY` for the `opencode-go` provider.
