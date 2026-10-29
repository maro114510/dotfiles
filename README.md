# dotfiles

Personal macOS development environment configuration files managed with chezmoi.

This procedure supports **Apple Silicon** Macs only. `mise.lock` is resolved for `macos-arm64`, so Intel Macs are out of scope.

## Prerequisites: Homebrew and chezmoi

Homebrew is the bootstrap layer: it installs chezmoi, mise, and the CLI tools that chezmoi does not manage.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
```

Check:

```bash
brew --version
chezmoi --version
```

## 1. Initialize chezmoi

Clone the repository at the path the tracked config expects as its source, and apply it in the same run:

```bash
chezmoi init --apply --source ~/ghq/github.com/maro114510/dotfiles \
  https://github.com/maro114510/dotfiles.git
```

`--source` is required: `.chezmoi.toml.tmpl` sets `sourceDir` to `~/ghq/github.com/maro114510/dotfiles`, so a source anywhere else makes every later `chezmoi apply` fail.

During initialization, chezmoi will interactively ask for:

| Prompt | Example | Notes |
|---|---|---|
| Default git email | `you@example.com` | Used as the fallback email in all repos |
| Work project directory | `~/ghq/github.com/yourcompany/` | Leave empty to skip; trailing `/` required |
| Work git email | `you@yourcompany.com` | Leave empty to skip |
| Personal project directory | `~/ghq/github.com/yourhandle/` | Leave empty to skip; trailing `/` required |
| Personal git email | `you@personal.example.com` | Leave empty to skip |

Check:

```bash
chezmoi source-path
# must print /Users/<you>/ghq/github.com/maro114510/dotfiles
```

The first apply exits non-zero at the Raycast extension step because Bun is a mise tool and mise has not installed anything yet. That is expected; step 6 runs the step again once Bun exists.

The applied environment only reaches new shells, so open a login shell before continuing (it also makes `~/.local/bin` and the mise shims available for the next steps):

```bash
exec zsh -l
```

Per-directory email override files (`~/.config/git/config.work`, `~/.config/git/config.personal`) are created automatically on first run if you provide the corresponding email. These files are **not** tracked by chezmoi — edit them directly if you need to change the email later.

To add a new directory context in the future:
```bash
chezmoi edit ~/.config/git/config
chezmoi apply
```

## 2. Install Homebrew packages

```bash
brew bundle --file="$HOME/.Brewfile"
```

This installs mise, git, sheldon, the CLI tools the shell config calls, and the GUI apps common to every Mac.

Check:

```bash
brew bundle check --file="$HOME/.Brewfile"
# exits 0 when every Brewfile entry is satisfied
```

## 3. Install mise tools

```bash
mise install --locked
```

`--locked` installs the versions recorded in `~/.config/mise/mise.lock` instead of resolving `latest` again, so two Macs get the same tool versions.

Check:

```bash
mise ls --missing
# prints nothing when every configured tool is installed
```

## 4. Apply the pnpm security policy

```bash
pnpm-policy.sh --apply
```

The script converges the four non-secret pnpm 12 settings described in [docs/npm-to-pnpm-migration.md](docs/npm-to-pnpm-migration.md). It needs the pnpm that step 3 installed.

Check:

```bash
pnpm-policy.sh --check
# pnpm 12 security policy: OK
```

## 5. Authenticate gh

`~/.config/git/config` uses `gh auth git-credential` as its credential helper, so git over HTTPS needs gh authenticated:

```bash
gh auth login
```

Check:

```bash
gh auth status
# Logged in to github.com account <you>
```

## 6. Set up the shell, editor, and Raycast

**Shell.** Open a login shell so `.zshenv`, `.zprofile`, and `.zshrc` load; this also installs the zsh plugins sheldon resolves from `~/.config/sheldon/plugins.toml`:

```bash
exec zsh -l
```

Check:

```bash
command -v mise starship sheldon
# prints one path per tool
```

**Editor.** The first Neovim launch clones lazy.nvim and installs the plugins pinned in `~/.config/nvim/lazy-lock.json`. Finish that headlessly:

```bash
nvim --headless "+Lazy! sync" +qa
```

Check: the command exits 0.

**Raycast.** Bun is installed now, so apply once more to run the pending Raycast `run_once` script, which runs `bun install --frozen-lockfile` and `bun run build`:

```bash
chezmoi apply
```

Then register the extension: Raycast → Import Extension → `~/.raycast/memo-search`.

Check:

```bash
(cd ~/.raycast/memo-search && bun run build)
# ready - built extension successfully
```

## 7. Verify the setup

Run every check in one pass:

```bash
chezmoi source-path
brew bundle check --file="$HOME/.Brewfile"
mise ls --missing
pnpm-policy.sh --check
gh auth status
chezmoi diff
```

`chezmoi diff` must print nothing, which means every managed file already matches the source. If it prints a diff, run `chezmoi apply` and check again.

## Bring changes to another Mac

The source checkout is a normal clone of this repository, so an existing Mac picks up changes from `main` with git, then applies them:

```bash
git -C "$(chezmoi source-path)" fetch origin main
git -C "$(chezmoi source-path)" switch main
git -C "$(chezmoi source-path)" merge --ff-only origin/main
chezmoi diff
chezmoi apply
```

Review `chezmoi diff` before applying: it lists exactly what `chezmoi apply` will change, and it should contain only the changes that came from `main`. After applying, `chezmoi diff` must be empty again.
