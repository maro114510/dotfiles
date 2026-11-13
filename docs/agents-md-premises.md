# AGENTS.md premises

The plan to remove `~/.claude/CLAUDE.md` and add DSH rests on three claims.
This page records what was observed for each, on which tool version, and what is still unconfirmed.

## Results

| Claim | Tool and version | Result | How it was checked |
|---|---|---|---|
| DSH loads the global `$DSH_HOME/AGENTS.md`, defaulting to `~/.dsh/AGENTS.md` | DSH 0.2.2-rc.1 | Confirmed from the installed source; the live session did not show the common body | Read the README of `@deepseek-ai/dsh-agent-instructions`, which `dsh-base` enables by default |
| A live DSH session loads a shared skill from `~/.agents/skills` | DSH, version not reported by the session, 2026-11-13 | Confirmed | Asked a new session what the `commit` skill does, and it described the skill's own steps |
| Claude Code with no `~/.claude/CLAUDE.md` loads `~/.claude/AGENTS.md` | Claude Code 2.1.323 | Unconfirmed | A fresh config directory has no login, and the logged-in one holds the live `CLAUDE.md`, which an unattended run must not move |
| The APM Claude target still deploys skills and agents without a `CLAUDE.md` | APM 0.35.0 | Confirmed | Observed in a temporary `HOME` |

## DSH

- The first request carries a baseline message with the user-global chain first, `$DSH_HOME/AGENTS.md` and then `<agentsHome>/AGENTS.md`, and the project chain after it.
- `$DSH_HOME` defaults to `~/.dsh` and `<agentsHome>` to `~/.agents`.
- A `CLAUDE.md` that duplicates an `AGENTS.md` is loaded once.

Live session on 2026-11-13, run by the user in the browser; the session did not report its version, and 0.2.2-rc.1 above is the version installed by pnpm for the source check:

- Asked what the `commit` skill does, the session described its steps, such as the secret screening and the `STOPPED: foreign changes` stop. These come from the skill file, so the shared skill was loaded.
- Asked to quote its instructions, the session declined. This neither confirms nor refutes that the managed `AGENTS.md` was loaded.
- Asked to write a completion report, the session used its own headings and not the conclusion, decision needed and next step order that the managed `AGENTS.md` asks for. This is a sign that the common body did not take effect, and it is not proof that it was not loaded.
- Still open: a new session that quotes the common body, or follows its reporting order.

## Claude Code

- The expected behavior is that Claude Code reads `AGENTS.md` only when no `CLAUDE.md` exists, from version 2.1.277. This was read from documentation and not observed.
- To confirm, move `~/.claude/CLAUDE.md` aside, put a unique sentence in `~/.claude/AGENTS.md`, start a new session, ask it to quote that sentence, then restore the file.
- Record the result here with the Claude Code version.
- The decision on this Issue is to remove `CLAUDE.md` with this claim unconfirmed.

## APM

Steps run, with `~/.claude` empty and no `CLAUDE.md` anywhere:

```bash
HOME=$tmp apm install -g
```

- The manifest was `dot_apm/apm.yml` without `maro114510/private-skills`, which a temporary `HOME` cannot fetch.
- `~/.claude/skills` received the skills, such as `commit` and `implement`.
- `~/.claude/agents` received `pr-owner.md` and `pr-verify.md`.
- Neither `CLAUDE.md` nor `AGENTS.md` was created.
