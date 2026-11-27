# OpenCode in CI

Turns a small Issue into a draft pull request in GitHub Actions without the owner's hand. The owner reviews it in the browser and merges or closes it.

## When a run starts

- issue-size labels a newly opened Issue `size/S`. Its label job then starts this workflow with `workflow_dispatch`, because a label that `GITHUB_TOKEN` adds starts no workflow, and a dispatch does. Only the run that issue-size started for the opening does this, so a later re-judged size starts nothing.
- The owner adds the `opencode` label, to run again.

Only Issues opened by the owner or maronium[bot] run. A run is separate from issue-size, so a later edit does not cancel it. An edit before issue-size finishes cancels issue-size itself, and then no run starts; the owner adds the `opencode` label instead.

The issue-size caller also needs Actions write to dispatch.

## Two jobs

No job holds both the model key and a token that can write. The model can write the key into the patch, so both jobs refuse a patch that holds it; see Blocks.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, read-only access | Reads the Issue once through the API, runs OpenCode on its title and body, and hands over a patch |
| Publish | `GITHUB_TOKEN` that can write | Applies the patch to the event's commit, refuses it as Blocks says, and opens a draft pull request |

Each repository allows GitHub Actions to create pull requests. A pull request that `GITHUB_TOKEN` opens starts no `pull_request` workflow, so a required check never reports and the ruleset blocks the merge. Starting the check with `workflow_dispatch` on the pull request's branch does not help: GitHub does not count a dispatched run toward a ruleset's required check. The pull request's body therefore asks the owner to close and reopen it, and the reopening, which a person does, starts the `pull_request` run. A GitHub App or a personal access token would start it without that click, but it would hold a writing credential beside Publish, so the design does not use one.

## Model and key

- The model is `opencode-go/deepseek-v4.1-flash` on the owner's OpenCode Go plan.
- The key belongs to a service account, can only call models, expires after 30 days, and has a `$0` budget. The budget blocks every spend that counts toward budgets, and Go usage within the plan does not count. It does not cover a model on an own provider without a price, so the workspace must have no such provider; with one, a leaked key can spend beyond the Go allowance.
- The model can read the key through its shell. If it leaks, the worst case is the month's Go allowance, which local work shares.

## Layout

A reusable workflow in this repository, called from each repository as with issue-size, and run apart from it. Its scripts are in `.github/scripts/` and are fetched from `main`, as issue-size does. A caller in each repository starts it on the `opencode` label or by hand with an Issue number, and passes the key as the `OPENCODE_API_KEY` secret.

The branch is `opencode/issue-<Issue>-<run id>-<attempt>`, so a rerun never meets an earlier branch. The pull request's title and body are fixed text and copy nothing from the Issue or the model. OpenCode is pinned by version and checksum in the reusable workflow, and its project config is off.

## Blocks

The key is a service account key that can only call models, so a leaked key cannot be revoked by a run. A run refuses it before it can leave.

- Generate refuses staged changes holding `oc_sk_` or this run's key, so the artifact never holds the key. Publish refuses `oc_sk_` again. Both search the staged content as text and not the patch, because git stores a binary file, or any file that `.gitattributes` marks binary, as compressed base85.
- Publish refuses files whose path has a segment `.git`, `.github`, `.opencode`, `.envrc`, `.mise`, `mise.toml`, `.mise.toml`, `mise.local.toml`, or `.mise.local.toml`, at any depth and in any letter case.
- OpenCode's denials come from `OPENCODE_CONFIG_CONTENT`, and a project config is switched off with `OPENCODE_DISABLE_PROJECT_CONFIG`, so a file in the checkout cannot loosen them.
- The artifact is kept for one day.

## Appendix

Items this design does not cover, listed without a decision.

### Requests

- Fixing an existing pull request from a comment on it.
- Running OpenCode on Issues already open when this is deployed.
- A queue or a limit on concurrent runs.
- Replacing the 30-day key on schedule; a run after it expires fails.
- A separate Go plan for CI, so a leak cannot stop local work.
- Enforcing that the workspace has no own provider without a price.

### Paths

- A local agent acting as the owner opens an Issue or adds the `opencode` label after reading steering text.
- An Issue body written by maronium[bot] carries steering text from what its agent read.
- maronium[bot] adds the `opencode` label, which starts a run as the owner's label does.
- The model reaches the network or files outside the checkout through its shell.
- The admin merges a draft in maro114510/skills without approving its checks.
