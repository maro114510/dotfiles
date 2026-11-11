# pi-claude-code

[pi-claude-code](https://github.com/earendil-works/pi-claude-code) routes Pi's Claude requests through `claude -p`, so they draw from the Claude subscription.
Its README warns that Anthropic may move `claude -p` usage to separate, API-priced billing.
This page records what was measured and how to notice that change.

## Check the state

Run `/claude-code-status` in Pi.

Healthy output:

```text
Claude Code is installed and logged in (max)
```

Anything else: run `claude auth status`, then `claude auth login`.

## Quota cost of a fresh Claude Code process

Branching, editing an earlier message, or changing settings starts a fresh `claude` process that replays the conversation.
Measured on 2026-11-11 with Pi 1.5.0, Claude Code 2.1.316, pi-claude-code `d5b5e04`, and a 21k-token conversation driven through `pi --mode rpc`.

| Step | New process | Input | Cache read | Cache write |
|---|---|---|---|---|
| First prompt | yes | 2 | 627 | 21,027 |
| Continuation | yes | 4 | 21,350 | 317 |
| Continuation | no | 4 | 21,667 | 29 |
| First response after a fork at the latest message | yes | 4 | 21,667 | 16 |
| First response after a thinking-level change | no | 4 | 21,716 | 18 |
| First response after a fork at an earlier message | yes | 4 | 21,653 | 16 |
| First response after switching Sonnet 5.5 to Haiku 5.5 | yes | 2 | 0 | 21,687 |
| Continuation on Haiku 5.5 | no | 4 | 627 | 21,091 |

- A fork or an edit replays from the prompt cache, so its extra cost is close to zero while the cache is warm.
- A model switch writes the whole history to the cache again, because the cache is per model.
- Claude Code writes the cache with a one-hour lifetime. A replay after an hour of inactivity costs a full cache write, like the model switch.
- On Haiku 5.5 the continuation missed the cache too. This was observed once and not explained.

## Detect a billing change

| Signal | Where | What to look for |
|---|---|---|
| Pi stops with `Claude Code billing:` | Any Pi session | Anthropic charged or wants to charge usage credits. Pi does not retry |
| Anthropic's notice | [Use the Claude Agent SDK with your Claude plan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) | An `Update <date>` line newer than October 7, 2026 |
| Extension changes | The pi-claude-code commit log, README, and `src/billing.ts` | Commits after `d5b5e04` |

The extension has no CHANGELOG, so read its commit log instead.
Leave `PI_CLAUDE_CODE_ALLOW_USAGE_CREDITS` unset, so the first credit charge stops Pi.

## Monthly check

On the first working day of each month:

1. Run `/claude-code-status` in Pi.
2. Read the Anthropic notice and compare its newest `Update` date with the one above.
3. List the extension's new commits:

   ```bash
   ext=~/.pi/agent/git/github.com/earendil-works/pi-claude-code
   git -C "$ext" fetch origin
   git -C "$ext" log --oneline HEAD..origin/main
   git -C "$ext" diff HEAD origin/main -- README.md src/billing.ts
   ```

4. If either changed, read the change, then apply it with `pi update https://github.com/earendil-works/pi-claude-code`.
5. Update the date and commit on this page.

If `claude -p` stops drawing from the subscription, switch `defaultProvider` in `dot_pi/agent/modify_settings.json` away from `claude-code`.
