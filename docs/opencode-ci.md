# OpenCode in CI

Turns a small Issue into a draft pull request in GitHub Actions without the owner's hand. The owner reviews and merges, so CI saves the owner's time on small edits and decides nothing that reaches `main`.

When goals conflict, keeping secrets and write access away from anyone but the owner comes before how many Issues a run can finish, and a simple workflow comes before using the quota fully.

Out of scope: judging whether an Issue should be done, reviewing, and working on an existing pull request.

## When a run starts

| Event | Starts a run |
|---|---|
| issue-size labels a newly opened Issue `size/S`, and the Issue was opened by the owner or maronium[bot] | Yes, once |
| The owner adds the `opencode` label to an Issue opened by the owner or maronium[bot] | Yes, each time the label is added |
| An edit, a re-judged size, a comment, a label added by anyone else, an Issue opened by anyone else, a pull request, or any other event | No |

- The automatic run belongs to the issue-size workflow, as a job after the label job. A label that `GITHUB_TOKEN` adds starts no other workflow, so a separate workflow could not follow it.
- Only an Issue's opening starts the automatic run, so editing an Issue never spends the quota again. Issues already open when this is deployed are never run automatically.
- The owner is the repository owner as GitHub reports it: the Issue's author for the first row, and the event's sender for the second. Both checks run in the job's condition, before any step can read a secret.

Nobody reads the Issue before the model does. The owner's local agents open Issues under the owner's account, and maronium[bot] opens them for its agents, so text that steered one of those agents reaches the model unread. This is accepted, because a run can only produce a draft pull request and spend the quota below.

## Two stages

A run is two jobs, so that no job holds both the model and a token that can write.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, and a read-only token | Runs OpenCode on the event's commit and hands over a patch |
| Publish | `GITHUB_TOKEN` with Contents and Pull requests write, and no outside secret | Applies the patch to the event's commit, checks the result, pushes a new branch, and opens a draft pull request |

- Publish takes the commit from the event, never from Generate. Every value Generate hands over is untrusted, because the model's shell can write any of Generate's outputs.
- Publish runs no model and no code from the patch.
- Publish opens the pull request as a draft itself, so the draft does not depend on the model.
- Publish names the branch from the Issue number and the run, and fails if the branch exists, so it never moves an existing branch.
- The pull request's title and body are Publish's own text with a link to the Issue. Neither copies the Issue nor the model's summary, so merging closes no other Issue and mentions nobody.
- Generate gets no cache access, as issue-size does.

### What Publish refuses

Publish checks the tree after applying the patch, not the patch text, because a patch can reach a path its text does not name. It lists every changed path, with renames split into their old and new paths, and refuses the whole patch when any of these holds:

- A path is under `.github/`.
- A path is a file that runs code on checkout or when a tool starts in the directory: `mise.toml`, `.mise.toml`, `mise/`, `.mise/`, `.tool-versions`, `.envrc`, `.gitattributes`, and `.gitmodules`. The owner's mise trusts every config under `~/ghq`, so checking out the branch and running any tool would run the model's code before the owner reads it.
- A file is a symbolic link or a submodule, or the change is binary.
- The patch contains text in the model key's format, `oc_sk_`.

Issues whose fix needs one of these files are fixed by hand.

A refusal does not keep the key secret: the patch was already stored as an artifact that anyone who can read the repository can download. A refusal for the key's format therefore means revoking the key. Artifacts are kept for one day.

## What the model reads

- The Issue's title and body as the event carried them, so a later edit does not change what the model reads.
- No comment. Context the owner wants the model to use goes into the body before the run.
- The checkout of the event's commit, with its instruction files.

## What the model may do

- Read and edit files in the checkout, and run shell commands, so it can run tests.
- OpenCode's own web fetch, web search, and access outside the checkout are denied in a config the workflow writes before the run. OpenCode runs at a pinned version with automatic approval, so nothing waits for an answer and the explicit denials still hold.
- A fixed time limit ends the job.
- It has no Git credentials: the checkout keeps none, and the job's token can only read.

The shell runs with the runner's full file, process, and network access, so the denials above stop only OpenCode's tools. The shell can read the model key and send it out, and outside content can reach the model through it. That is accepted because of the limits below.

## Model, key, and quota

| Item | Decision | Why |
|---|---|---|
| Model | `opencode-go/deepseek-v4.1-flash` | The owner's OpenCode Go subscription |
| Data region | The workspace allows Global, the region this model needs | Accepted for every repository, public and private, to match the owner's local use |
| Key | A service account key in the owner's workspace, restricted to calling models, expiring after 7 days and replaced weekly | A leaked key can do nothing else, and stops working within a week |
| Budget | `$0` for that service account | Blocks spend paid from credits; Go usage within the plan does not count toward budgets |

- This needs the Go or Go Plus plan, which covers the workspace's API keys. Go Teams does not cover service accounts, so every request would fail under the `$0` budget.
- The workspace has no provider of its own. A provider without a price does not count toward budgets, so a leaked key could spend on it without limit; one added later needs a price.
- CI and the owner's local sessions share one Go allowance. A leaked key can spend up to the weekly limit, half the monthly allowance, before it expires, and local work then stops until the weekly limit resets.
- Runs are not queued or limited in number.
- The model's zero data retention depends on the provider's agreement, which OpenCode renews monthly.

## Repository settings

Each repository allows GitHub Actions to create and approve pull requests. Without it, `GITHUB_TOKEN` cannot open the pull request. The same setting lets the token approve one, which changes little where no approval is required.

## Merging

The checks on a pull request from `GITHUB_TOKEN` start only after a person with write access approves them in the merge box.

| Repository | A draft merged without approving its checks |
|---|---|
| maro114510/skills | Possible: the admin role bypasses the main ruleset through GitHub's bypass prompt. Accepted |
| maro114510/dotfiles | Impossible: its main ruleset has no bypass |

## Layout

The behavior lives in reusable workflows in this repository. Each repository's caller holds the triggers, the permissions, and the author checks, as with issue-size.

## Not yet checked

- That OpenCode reads the key from `OPENCODE_API_KEY` for the `opencode-go` provider.
- That Publish can open the pull request once the repository setting is on.
