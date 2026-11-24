# Agent writing-rule checks

Source: `dot_local/share/agent-writing-rules/`, applied to `~/.local/share/agent-writing-rules/`.
The web profile of DeepSeek Harness links its `dsh/` bundle, so the check runs in every Web session after `chezmoi apply`.

## Layout

| Path | Role |
|---|---|
| `rules.mjs` | The checks, as plain JavaScript with no harness import, so another harness can load the same file |
| `dsh/` | The DeepSeek Harness bundle that applies the checks |

## What it does

| Rule in the shared instructions | Check | Result in DeepSeek Harness |
|---|---|---|
| No space between a Japanese character and an adjacent alphanumeric | The reply that ends a turn | The agent gets the reason and rewrites the reply, at most twice per human message; the third attempt reaches the human |
| No parenthetical asides | The reply that ended the previous turn | The next human message carries a warning to the agent; the reply is never sent back |
| Delete with `trash`, not `rm` | Each `bash` call | The command runs, and the agent gets a warning with the paths outside the temporary directories |

- Code spans, code blocks, URLs, and paths are exempt from the spacing and aside checks, and so are Markdown link targets from the aside check.
- `/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, and `$TMPDIR` count as temporary; a target whose value the command does not show, such as `"$dir"`, does not.
- The send-back count is read from the session log, so a resumed session keeps it.

## Limits

- The human sees each reply that was sent back, followed by its rewrite, because the turn shows every step as it streams.
- An aside warning reaches the agent only with the next human message, because context added while a turn stops opens another step.
- Only DeepSeek Harness applies the checks so far; the other harnesses still rely on the shared instructions alone.
