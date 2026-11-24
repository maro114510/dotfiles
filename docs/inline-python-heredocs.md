# Inline Python heredocs

Agents often run `python3 - <<'EOF'` to rewrite a file. This page records what those scripts do, which ones got a helper, and why the others did not, so the decision is not made again.

## What was measured

The sample is the local session logs of three agent tools for the 8 days before 2026-11-24.

| Item | Value |
|---|---|
| Heredoc calls | 2471 |
| Sessions with at least one | 188 |
| Distinct scripts, after dropping repeats inside a session | 842 |

- A script is counted once, in the first group whose keyword matches it.
- Grouping is by keyword, so each count is approximate.
- The source and window differ from the weekly review that raised the Issue, so these counts cannot be compared with its 421 calls.
- One tool's logs hold most of the scripts, so the picture mostly describes that tool.

## Purposes

| Purpose | Distinct scripts | Sessions | Decision |
|---|---|---|---|
| Literal string replace in a file | 479 | 140 | Helper: `file-replace` |
| Other file rewrite, such as cutting a range between two markers | 53 | 33 | No helper |
| Regex substitution in a file | 22 | 16 | No helper |
| JSON file rewrite | 14 | 9 | No helper |
| Print part of a JSON result from a CLI or API | 47 | 11 | No helper |
| Query an agent session log | 38 | 14 | No helper |
| Text lint or regex extract | 44 | 21 | No helper |
| Date or time arithmetic | 42 | 15 | No helper |
| Other one-off checks | 101 | 38 | No helper |
| YAML or TOML read | 2 | 2 | Below the threshold of three sessions |

## Why a helper for literal replace

- 148 of the 173 sessions that wrote a literal-replace heredoc had the edit tool.
- Over the same period the edit tool was called 252 times and failed twice, so it works and is not chosen.
- 526 of 595 such calls chained a check, such as a diff or a test run, after the heredoc, so the habit is one call that edits and then checks.
- 233 of 479 scripts changed several places or several files, and 276 held a multi-line string.
- 258 of 479 contained a backslash, and Python reads `\n` inside a normal string as a newline even when the heredoc is quoted, so such a replacement can be written wrong without any error.

`dot_local/bin/executable_file-replace` takes SEARCH/REPLACE blocks on stdin, so nothing is escaped, and the call can be followed by a check.

- Every block must match exactly one place, and no file is written unless all do.
- A block sees the result of the blocks before it on the same file.
- The format is the search and replace block that Aider documents as its diff edit format.

A stricter or lighter form was considered and not chosen.

| Option | Why not |
|---|---|
| Instruction to use the edit tool only | The edit tool was already available and was not chosen, and it cannot chain a check. |
| `git apply` with a unified diff | The line numbers must be right, and an agent writing a diff by hand gets them wrong. |
| `apply_patch` from Codex | It ships inside the Codex binary and is not on every agent's path. |
| A Python helper | It brings back the language whose string rules caused the problem. |

The shared instruction names `~/.local/bin/file-replace` by its full path, because the shell an agent runs commands in does not always have `~/.local/bin` on its path.

## Why no helper for the rest

| Purpose | Reason |
|---|---|
| Other file rewrite | Each one cuts or moves a different range by its own rule. A small range is covered by a multi-line block in `file-replace`. Revisit if the next measurement shows large ranges still go to heredocs. |
| Regex substitution | The pattern is the content, and it differs every time. A helper would only wrap `perl -pi`. |
| JSON file rewrite | `jq` covers it and is installed. |
| Print part of a JSON result | `jq` covers the simple cases, and the rest are one-off aggregations. |
| Query an agent session log | The log format is private to each tool and changes between versions, and each query answers a different question. |
| Text lint or regex extract | Each is a one-off analysis with no shared shape. |
| Date or time arithmetic | Most convert an epoch to a local time inside a larger analysis. `date -r <epoch>` covers the standalone case. |
| Other one-off checks | No shared shape. |

## Measuring again

The acceptance condition on the number of heredoc calls one week after the helper lands is tracked in its own Issue, because a person or a scheduled run measures it and a checkout cannot.

- The count of `python3 - <<` calls is not enough, because calling `file-replace` through a heredoc would lower it without changing the effort.
- The measurement should also count calls to `file-replace` and the literal-replace heredocs that remain.
