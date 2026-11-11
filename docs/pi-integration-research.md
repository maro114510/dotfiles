# Pi integration with the existing workflow

Research note for Pi 1.5.0. Implementation is out of scope.

## Conclusion

- Run Pi interactively inside the existing workflow.
- Build no adapter or runner on RPC or the SDK.
- Do one small thing: install Herdr's built-in Pi integration.

## Sources

| Source | Where |
|---|---|
| Pi docs `cli-integration.md`, `rpc.md`, `sdk.md`, `security.md`, `skills.md`, `tmux.md` | `$(mise where pi)/pi/docs/` |
| Pi CLI flags | `pi --help` |
| Herdr integrations | `herdr integration status`, Herdr 0.9.5 |
| Workflow config | `dot_zshrc`, `dot_config/herdr/`, `dot_config/opencode/`, `dot_apm/apm.yml`, `.chezmoitemplates/agents/common.md` |

## Pi's integration surfaces

| Surface | Interface | Lifetime | Fits |
|---|---|---|---|
| Interactive | Terminal UI | Until the user exits | A person working in a pane |
| Print `pi -p` | Final text on stdout | One run | A script that needs only the final answer |
| JSON `--mode json` | JSONL events on stdout | One run | A process that needs progress and tool events |
| RPC `--mode rpc` | JSONL commands, responses, and events | Long-lived | Another process steering Pi, such as an IDE |
| SDK `@earendil-works/pi-coding-agent` | In-process TypeScript | Host-owned | A Node.js or Bun host |

Caveats the docs state:

- Print mode exits nonzero on an `error`, `aborted`, or `length` stop.
- JSON mode does not exit nonzero for a failed response, so a caller must read the events.
- RPC `prompt` success means accepted, not finished; wait for `agent_settled`.
- RPC framing must split only on LF, so Node.js `readline` is unsafe.
- RPC and print cannot show the trust prompt, and TUI-only extension UI is unavailable or degraded.
- SDK sessions do not load the CLI's built-in `codemode`, `tool_search`, and MCP extensions unless the host adds them.

## Touchpoints

| Workflow part | How Pi meets it | Needed |
|---|---|---|
| git-wt worktrees | Pi uses the working directory for context files, project resources, and session grouping under `~/.pi/agent/sessions/` | Nothing; start Pi in the worktree |
| Project trust in new worktrees | A trust prompt appears only when the folder has `.pi/` resources or a project `.agents/skills`. Saved decisions apply to subdirectories | Nothing now; `/trust` on a parent directory if a repo ever ships `.pi/` |
| Herdr | Herdr ships a Pi integration, an extension at `~/.pi/agent/extensions/herdr-agent-state.ts`; `herdr integration status` reports it `not installed` | `herdr integration install pi` |
| tmux | `tmux.md` asks for `extended-keys` so `Shift+Enter` differs from `Enter`; `dot_tmux.conf` does not set it | Only if Pi runs in tmux and `Shift+Enter` submits |
| difit | A CLI that skills call through the shell; Pi's `bash` tool runs it like any harness | Nothing; the guard extension must not block it |
| Shared skills | Pi discovers `~/.agents/skills/`, where APM installs `difit`, `difit-review`, and `herdr` | Nothing |
| Shared instructions | `dot_pi/agent/AGENTS.md.tmpl` renders the same `agents/common.md` that OpenCode uses | Nothing |
| OpenCode permissions | Pi has no permission prompt; `opencode.jsonc` rules do not apply | Covered by the guard extension, not by integration |
| OpenCode subagents and plugins | OpenCode-only assets; Pi has subagents only as an example extension in `extensions.md` | Nothing; keep them in OpenCode |
| Scripts that take an agent command | A skill that runs `<agent command> <prompt>` can take `pi -p` | Nothing until a concrete script needs Pi |

## Recommendation

### Do

- Install the Herdr Pi integration with `herdr integration install pi`, the same imperative step as the other harnesses.
- Keep its generated file out of chezmoi, like the Claude and OpenCode Herdr files in `.chezmoiignore`, because Herdr owns and versions it.
- Keep `difit` and `npx difit` allowed when the guard extension lands.

### Don't, the YAGNI line

| Not built | Why |
|---|---|
| An RPC or SDK runner that drives Pi from OpenCode or scripts | No workflow step needs another process to steer Pi; Herdr panes and worktrees already isolate runs |
| A Pi port of OpenCode subagents or orchestration | OpenCode keeps that role; a second copy would drift |
| A JSON-event parser or wrapper around `pi -p` | `pi -p` already exits nonzero on failure; build one only when a script needs Pi's tool events |
| Pi-specific copies of skills or instructions | Pi already loads the shared ones |
| A Pi fork via `piConfig` | No need for a renamed CLI or config directory |

Revisit when a concrete job needs one of these, such as a script that must stream Pi's tool events.
