# Execution posture

What each agent tool on this machine is allowed to do without asking.
The most permissive tool sets the effective ceiling for all three, so a rule that only one tool enforces is not a rule for the others.
Read a cell as what the tool does today, and a gap as a fact to accept or close, not as a promise.

## Summary

| Dimension | Claude Code | Codex | OpenCode |
|---|---|---|---|
| Write scope | Anywhere the user can write, minus the deny list | Anywhere, with no sandbox | Anywhere, minus the deny list; paths outside the project and home ask |
| Approval | Auto mode, set per machine | Never asks | Asks only for the listed irreversible actions |
| Network | Unrestricted by the tool; `curl`, `wget`, and `nc` denied | On | Every URL allowed |
| Without confirmation | Whatever the machine's allow list names | Everything | Everything that no rule asks about or denies |

## Claude Code

| Dimension | Posture |
|---|---|
| Write scope | No sandbox. Edits to `.env*` and `secrets/` are denied, and reads of keys, tokens, credentials, `~/.ssh`, and `~/.aws` are denied |
| Approval | `defaultMode` is `auto`, and the dangerous-mode prompts are skipped. Each machine keeps its own value, because the settings template never overwrites it |
| Network | The tool does not restrict it. Shell `curl`, `wget`, and `nc` are denied, and fetching a page needs a per-domain `WebFetch` entry in the machine's allow list |
| Without confirmation | Every command in the machine's allow list, which today includes read-only inspection, builds and tests, `git fetch`, and `git push`. The managed list adds only denies, such as `sudo`, `rm`, `git reset`, `git rebase`, and the database clients |

- Enforced by `dot_claude/settings.json.tmpl`, which overlays the shared deny rules and keeps every other key as the machine has it.
- Gap: a force push is not denied.

## Codex

| Dimension | Posture |
|---|---|
| Write scope | `sandbox_mode` is `danger-full-access`, so nothing is confined |
| Approval | `approval_policy` is `never`, so no action waits for the user |
| Network | `network_access` is on |
| Without confirmation | Every action |

- Enforced by nothing in this repository: `dot_codex/private_config.toml.tmpl` keeps each setting as the machine has it and only refuses to trust the filesystem root and the home directory.
- Gap: this tool sets the ceiling. It has no deny list, so the secret-file and destructive-command rules of the other two tools do not hold here.

## OpenCode

| Dimension | Posture |
|---|---|
| Write scope | Reads of secret files are denied, edits to `.env*` and to its own global config are denied, and a path outside the project asks, except home, the temporary directories, and the denied `~/.ssh` and `~/.aws` |
| Approval | Shell is allowed by default and asks for a recursive delete, a command that loses uncommitted work, a force push or remote ref delete, a `gh` delete or secret write, a new package, a cloud or database change, and a wrapper that runs a string |
| Network | Every URL is allowed |
| Without confirmation | Every shell command that no rule asks about or denies |

- Enforced by `dot_config/opencode/opencode.jsonc`, whose `sudo`, disk-erase, and secret-path denies come last so that no exception re-allows them.
- Gap: the rules match command text, so `bash -c` bodies, scripts, and `git -C` forms are not reliably caught.

## Widening

Widening is any change that lets a tool do something without asking, or reach something it could not before, in any cell above.

- Only the human widens a posture. An agent may propose it and may never apply it.
- The change lands as one pull request that edits this record and the tool's own configuration together, and the human merges it. A later `chezmoi apply` is the moment it takes effect.
- A change to the record that no configuration backs, or the reverse, is a defect.
- Narrowing needs no approval, and is recorded in the same way.
- When the most permissive tool widens, the new ceiling applies to every tool until the others catch up, so the pull request names that follow-up.
