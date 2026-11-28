# DSH guard plugin

Source: `dot_local/share/dsh-guard/`, applied to `~/.local/share/dsh-guard/`.
The web and headless profiles link it as a bundle, so DSH loads it in every project; no setting enables it.
It follows the [Pi guard](pi-guard.md), whose path rules it keeps, and refuses instead of asking.

## What it does

Every rule is a refusal. The shared policy sets approval `never`, which makes DSH reject a question unanswered, and approval `ask` would stop an unattended run at its first question. Each refusal names the safe alternative.

| Target | Refused |
|---|---|
| A read of a file or directory | `.env*` except `*.env.example`, `*.env.sample`, `*.env.template`; `*.pem`; `*.key`; `*id_rsa`; `*id_ed25519`; `*credentials.json`; anything under `.ssh/` or `.aws/` |
| A read of a credential file | OpenCode's `.config/opencode/service.json` and `.local/share/opencode/auth.json`; DSH's `.dsh/.credentials.yaml` and `.dsh/plugins/subscriptions/auth.json` |
| A write | `.env*`, anything under `.ssh/` or `.aws/` |
| A write of agent configuration | The OpenCode config and plugins, Pi's `settings.json` and extensions, and for DSH `.dsh/AGENTS.md`, `.dsh/cordis.patch.yml`, `.dsh/web-launch.conf`, `.dsh/profiles/`, `.dsh/plugins/`, `.config/dsh/`, and `.local/share/dsh-guard/` |
| `sudo` | Always |
| `git reset --hard` | Always |
| `git push` | `--force`, `-f`, a `+` refspec, `--delete`, `-d`, a `:` refspec; `--force-with-lease` and `--force-if-includes` pass |
| `gh` | A `delete` or `*-delete` subcommand, and `gh api` with `DELETE` |
| `rm` with a recursive flag | A target outside temporary directories and the repository's worktrees |

- A path is checked in any letter case, resolved against the session's working directory, and through its symlink target.
- A config or credential path matches under any parent directory.
- The path rules hold every entry of the Pi guard's, and a test keeps that true. The DSH entries are the addition.
- The rules are constants in the plugin, so no setting changes them.

## Recursive `rm`

A target passes when its real path lies strictly inside one of these, and fails otherwise.

| Place | Notes |
|---|---|
| A temporary directory | `/tmp`, `/var/tmp`, `/var/folders`, `$TMPDIR`, and their real paths; the directory itself fails |
| A worktree of the repository that the working directory belongs to | From `git worktree list`; the root, anything under `.git`, and a directory that holds another worktree fail |

- A `cd` earlier in the same command moves the directory that a relative target lives in; a `cd` the guard cannot read, such as `cd "$DIR"`, makes later relative targets fail.
- A target with a shell variable other than `$TMPDIR`, a command substitution, or `~user` fails.
- A recursive `rm` fed by `xargs` fails, because its targets are not in the command.
- The shell tool's `workdir` argument sets the directory of its command.

## Which calls it sees

| Call | How |
|---|---|
| A built-in or dsh-ops tool | Any string under a path key, such as `path`, `file_path`, `files`, `from`, `to`, or `root`, at any depth |
| `apply_patch` | The files its patch text adds, updates, deletes, or moves to |
| `bash`, `ops_bash` | The command, with quotes, redirections, wrappers such as `env` and `xargs`, `bash -c`, `eval`, and heredocs that feed a shell resolved |
| A call made through `run_code` | The same guard, because DSH dispatches each nested call through the shared pipeline with the outer call as its parent |

A tool decides its mode by name. A name with `write`, `edit`, `replace`, `remove`, `delete`, `mkdir`, or `patch` is a write, one with `copy`, `move`, or `batch` is both, `str_replace_editor` is a write except for `view`, and any other name is a read.

## Operational rules

- DSH has no security boundary here.
  - The guard reduces mistakes; it does not stop a hostile model.
  - The shared policy still sets full access with approval `never`.
- Restore the guard with `chezmoi apply`.
  - The guard refuses writes to its own directory, but the model can still rewrite it through `bash`.
  - The profile links the directory, so a tampered copy takes effect at the next DSH start, and `chezmoi apply` restores it.
- Change the rules in the source, never in `~/.local/share/dsh-guard`.
- A new tool that names its path argument in another way needs its key added to the plugin.

## Limits

- The guard sees tool arguments only, never what the call does.
- A shell can still reach a protected path indirectly.

| Bypass | Example |
|---|---|
| Reading a secret through `bash` | `cat`, `grep`, or `cp` on a secret file |
| Writing a protected location through `bash` | A redirect into `~/.ssh/config` |
| A command the rules cannot see | A command in a variable, a command substitution inside double quotes, `script_path` of `ops_bash`, a script file, or input sent to a terminal with `terminal_send` |
| A wrapper the guard does not look past | `timeout 5 rm -rf x`, `nice rm -rf x`, `find . -exec rm -rf {} +` |
| An unlisted destructive command | `git clean`, `git checkout -- .`, `git branch -D` |
| An unlisted secret file | A token in a file whose name matches no pattern |
| A search that reaches a secret below its root | `grep` rooted at the home directory finds a `.env` file under it |
| A subshell | `(cd /tmp); rm -rf build` counts the `cd` |
| A symlink the guard cannot resolve | A link made through `bash` to a file that does not exist yet |

## Verify

```bash
CHEZMOI="$(command -v chezmoi)" bats .github/testdata/dsh-guard-plugin.bats .github/testdata/dsh-config.bats
```

Manual checks in a DSH session, after `chezmoi apply` and a restart of the Web GUI:

- Reading `.env` and `~/.ssh/config` is refused, and reading `.env.example` works.
- `git reset --hard` is refused with the alternative named.
- The same calls made through `run_code` are refused alike.
