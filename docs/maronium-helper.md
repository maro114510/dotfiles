# maronium-helper

Hands an agent a GitHub App installation token for one repository. The App,
maronium, is the identity the agents act as where the person reviews and merges:
pull requests and comments carry the Bot's name, the person can approve their own
review target, and orchestrate-epic can tell the agents' records from the person's.

The helper exists so the App's private key never leaves 1Password's control in a
usable form: a background process reads it once, keeps it in memory, and answers
with a token scoped to the repository the command asks about. The key, a JWT, and
a token never appear in a process argument, in a file, or in a log.

## Setup

The App is created once, by hand, on GitHub. It needs Contents, Pull requests,
Issues, and Commit statuses as read and write, and Checks and Actions as read. It
never needs Workflows or Administration.

1. Store the App's private key in 1Password and note its `op://` reference.
2. Create the uncommitted local file `~/.config/maronium/helper.json`, readable
   only by you:

   ```json
   {
     "appId": "<the App's numeric ID>",
     "installationId": "<the installation's numeric ID>",
     "keyRef": "op://<vault>/<item>/<field>"
   }
   ```

   Nothing in this file belongs in the repository, and no identifier of this App
   is committed anywhere.
3. Check that a token comes back, using a repository the installation covers:

   ```bash
   maronium-helper token <owner>/<repo> >/dev/null && echo ok
   ```

   The first call after booting asks 1Password once. The process starts on the
   first call and stays until it is stopped or the Mac restarts.

## Commands

| Command | Behavior |
|---|---|
| `maronium-helper token <owner>/<repo>` | Prints an installation token for that repository, valid for at most an hour |
| `maronium-helper get` | Answers git's credential helper protocol for `github.com`, using the repository in the requested path; answers nothing for other hosts |
| `maronium-helper store`, `erase` | Accepted and ignored, as git expects |
| `maronium-helper stop` | Stops the background process |

The token carries Contents, Pull requests, Issues, and Commit statuses as write,
and Checks, Actions, and Metadata as read. It covers the one repository the
command names, and GitHub refuses the rest.

A repository outside the installation's account, or one the installation does not
cover, is refused with a reason and no token.

## Using it as git's credential helper

An agent that should act as the Bot gets the helper as its only credential helper
for `github.com`, with `credential.useHttpPath` turned on so the path names the
repository:

```bash
GIT_CONFIG_COUNT=3 \
GIT_CONFIG_KEY_0=credential.https://github.com.helper \
GIT_CONFIG_VALUE_0='' \
GIT_CONFIG_KEY_1=credential.https://github.com.helper \
GIT_CONFIG_VALUE_1='!maronium-helper' \
GIT_CONFIG_KEY_2=credential.https://github.com.useHttpPath \
GIT_CONFIG_VALUE_2=true \
git push
```

The empty value first clears the helpers the deployed git config registers for
`github.com`, which is `!gh auth git-credential`. A helper list is multi-valued,
so without the reset the person's own login answers first and this helper is never
asked.

Wiring this into the agents that orchestrate-epic and babysit start is the skills
repository's job; this file only provides the command.

## Limits

- The key is read once per process, including a failed read. After unlocking
  1Password, editing the local file, or changing the App, run
  `maronium-helper stop` and call the helper again.
- The process holds the key in its memory, so anything that can read its memory
  can read the key. Any process of the same user can also ask 1Password for the
  key while 1Password is unlocked; the sandbox that would have kept agents away
  from it was removed, and that gap is accepted.
- A token handed out stays valid for up to an hour on the one repository, even
  after the helper stops.
- Only one process serves the socket: a start that finds a live process exits
  instead of taking over.

## Tests

`bats .github/testdata/maronium-helper.bats` runs the helper against a fake GitHub
API and a fake 1Password, in a sandbox home. It covers the token's scope and
permissions, reuse and renewal around the ten-minute margin, one key read across
repositories, both refusals, the credential helper's answer and its silence, the
owner-only state directory, and that no token or key material reaches the disk or
the tracked files.
