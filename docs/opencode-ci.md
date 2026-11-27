# OpenCode in CI

Turns a small Issue into a draft pull request in GitHub Actions without the owner's hand. The owner reviews it in the browser and merges or closes it.

## When a run starts

- issue-size labels a newly opened Issue `size/S`. Its label job then starts this workflow with `workflow_dispatch`, because a label that `GITHUB_TOKEN` adds starts no workflow, and a dispatch does. Only the run that issue-size started for the opening does this, so a later re-judged size starts nothing.
- The owner adds the `opencode` label, to run again.

Only Issues opened by the owner or maronium[bot] run. A run is separate from issue-size, so a later edit does not cancel it. An edit before issue-size finishes cancels issue-size itself, and then no run starts; the owner adds the `opencode` label instead.

The issue-size caller also needs Actions write to dispatch.

## Two jobs

No job holds both the model key and a token that can write, except that the model can write the key into the patch, and Publish applies it. The Appendix leaves that open.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, read-only access | Runs OpenCode on the Issue's title and body, and hands over a patch |
| Publish | `GITHUB_TOKEN` that can write | Applies the patch to the event's commit, refuses it if it touches `.github/`, and opens a draft pull request |

Each repository allows GitHub Actions to create pull requests. The checks on such a pull request start after the owner approves them.

## Model and key

- The model is `opencode-go/deepseek-v4.1-flash` on the owner's OpenCode Go plan.
- The key belongs to a service account, can only call models, expires after 7 days, and has a `$0` budget. The budget blocks every spend that counts toward budgets, and Go usage within the plan does not count. It does not cover a model on an own provider without a price, so the workspace must have no such provider; with one, a leaked key can spend beyond the Go allowance.
- The model can read the key through its shell. If it leaks, the worst case is the month's Go allowance, which local work shares.

## Layout

A reusable workflow in this repository, called from each repository as with issue-size, and run apart from it.

## Appendix

Items this design does not cover, listed without a decision.

### Requests

- Fixing an existing pull request from a comment on it.
- Running OpenCode on Issues already open when this is deployed.
- A queue or a limit on concurrent runs.
- Replacing the 7-day key on schedule; a run after it expires fails.
- A separate Go plan for CI, so a leak cannot stop local work.
- Enforcing that the workspace has no own provider without a price.

### Paths

- A local agent acting as the owner opens an Issue or adds the `opencode` label after reading steering text.
- An Issue body written by maronium[bot] carries steering text from what its agent read.
- maronium[bot] adds the `opencode` label, which starts a run as the owner's label does.
- The model reaches the network or files outside the checkout through its shell.
- The patch artifact holds the key, and anyone who can read the repository downloads it.
- A file in the patch runs on checkout or when a tool starts, such as `mise.toml`, `.envrc`, or `.opencode/`.
- The admin merges a draft in maro114510/skills without approving its checks.

### Minimal blocks not in the design

- Refusing files that run on checkout, compared case-insensitively.
- Passing OpenCode's denials through `OPENCODE_CONFIG_CONTENT`, so a project config cannot override them.
- Taking the Issue body from the event, so a later edit does not change what the model reads.
- Writing the pull request's title and body without copying the Issue or the model's summary.
- Failing when the branch already exists.
- Keeping artifacts for one day, and revoking the key when a patch contains its format, `oc_sk_`.
