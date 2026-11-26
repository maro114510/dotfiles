# OpenCode in CI

Turns a small Issue into a draft pull request in GitHub Actions without the owner's hand. The owner reviews it in the browser and merges or closes it.

## When a run starts

- issue-size labels a newly opened Issue `size/S`, once per Issue.
- The owner adds the `opencode` label, to run again.

Only Issues opened by the owner or maronium[bot] run. An edit to the Issue does not cancel a run already started.

## Two jobs

No job holds both the model key and a token that can write.

| Job | Holds | Does |
|---|---|---|
| Generate | The model key, read-only access | Runs OpenCode on the Issue's title and body, and hands over a patch |
| Publish | `GITHUB_TOKEN` that can write | Applies the patch to the event's commit, refuses it if it touches `.github/`, and opens a draft pull request |

Each repository allows GitHub Actions to create pull requests. The checks on such a pull request start after the owner approves them.

## Model and key

- The model is `opencode-go/deepseek-v4.1-flash` on the owner's OpenCode Go plan.
- The key belongs to a service account, can only call models, expires after 7 days, and has a `$0` budget, so it cannot spend beyond the Go allowance.
- The model can read the key through its shell. If it leaks, the worst case is the month's Go allowance, which local work shares.

## Layout

A reusable workflow in this repository, called from each repository as with issue-size.
