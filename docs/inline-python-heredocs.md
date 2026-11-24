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
| Literal string replace in a file | 479 | 140 | `sd`, see below |
| Other file rewrite, such as cutting a range between two markers | 53 | 33 | No helper |
| Regex substitution in a file | 22 | 16 | No helper |
| JSON file rewrite | 14 | 9 | No helper |
| Print part of a JSON result from a CLI or API | 47 | 11 | No helper |
| Query an agent session log | 38 | 14 | No helper |
| Text lint or regex extract | 44 | 21 | No helper |
| Date or time arithmetic | 42 | 15 | No helper |
| Other one-off checks | 101 | 38 | No helper |
| YAML or TOML read | 2 | 2 | Below the threshold of three sessions |

## Why `sd` for literal replace

- 148 of the 173 sessions that wrote a literal-replace heredoc had the edit tool.
- Over the same period the edit tool was called 252 times and failed twice, so it works and is not chosen.
- 526 of 595 such calls chained a check, such as a diff or a test run, after the heredoc, so the habit is one call that edits and then checks.
- 233 of 479 scripts changed several places or several files, and 276 held a multi-line string.
- 258 of 479 contained a backslash, and Python reads `\n` inside a normal string as a newline even when the heredoc is quoted, so such a replacement can be written wrong without any error.

[`sd`](https://github.com/chmln/sd) is the widely used find-and-replace CLI, and `brew "sd"` installs it from the Brewfile.

- `sd -F -A OLD NEW files...` takes the text literally, across lines, in several files in one call, so the call can be followed by a check.
- It exits 0 when nothing matches and replaces every match, so an agent that needs exactly one match checks with `rg -cF` first.
- A CRLF file does not match an LF old text, and it still exits 0.

Measured on fresh sessions with only the instruction line as the condition:

| Instruction | Runs | `python3 - <<` heredoc | Tool named by the line |
|---|---|---|---|
| none | 8 | 4 | 0 |
| edit tool, not a heredoc; SEARCH/REPLACE blocks to a custom helper | 8 | 0 | 0 |
| edit tool, not a heredoc; `sd -F -A` | 9, over multi-file tasks | 0 | `sd` in 6 of 9 |

The 3 runs without `sd` rewrote a single large block with the write tool. The runs are few and the tasks were written for the test, so they show direction and not size.

Other tools were checked and not chosen.

| Tool | Why not |
|---|---|
| A custom helper that applies SEARCH/REPLACE blocks | It was not used in the runs, and `sd` covers the multi-file case. |
| `rg -r` | It prints the replaced text and writes nothing. |
| `fff` | It searches files and does not replace. |
| `ast-grep` | It matches syntax trees and cannot replace arbitrary text. |
| `fastmod` | It asks for each change unless told otherwise, and it expands `$1` in the replacement. |
| `git apply` | The agent must write correct hunk headers and context. |
| `apply_patch` from Codex | It ships inside the Codex binary, and a failed later file leaves the earlier ones written. |

## Why no helper for the rest

| Purpose | Reason |
|---|---|
| Other file rewrite | Each one cuts or moves a different range by its own rule. A small range is covered by a multi-line `sd -F -A`. Revisit if the next measurement shows large ranges still go to heredocs. |
| Regex substitution | The pattern is the content, and it differs every time. A helper would only wrap `perl -pi`. |
| JSON file rewrite | `jq` covers it and is installed. |
| Print part of a JSON result | `jq` covers the simple cases, and the rest are one-off aggregations. |
| Query an agent session log | The log format is private to each tool and changes between versions, and each query answers a different question. |
| Text lint or regex extract | Each is a one-off analysis with no shared shape. |
| Date or time arithmetic | Most convert an epoch to a local time inside a larger analysis. `date -r <epoch>` covers the standalone case. |
| Other one-off checks | No shared shape. |

The one-week recount is tracked in [a separate Issue](https://github.com/maro114510/dotfiles/issues/413).
