# dotfiles

Personal macOS development environment configuration files managed with chezmoi.

## Supported platform

Apple Silicon (arm64) Macs only. `mise.lock` resolves tool versions for
`macos-arm64`, and the Homebrew paths in the shell configuration assume the
Apple Silicon prefix (`/opt/homebrew`). Intel Macs are not supported.

```bash
uname -m   # arm64
```

## Setup

Follow the steps in order. Each step has a check command; do not continue until
it passes.

### 1. Install Homebrew and chezmoi

The Homebrew installer also installs the Xcode Command Line Tools when they are
missing.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install chezmoi
```

Check:

```bash
brew --version
chezmoi --version
```

### 2. Initialize chezmoi and check the source path

The managed `~/.config/chezmoi/chezmoi.toml` uses
`~/ghq/github.com/maro114510/dotfiles` as its source directory, so clone the
repository there before initializing.

```bash
mkdir -p "$HOME/ghq/github.com/maro114510"
git clone https://github.com/maro114510/dotfiles.git "$HOME/ghq/github.com/maro114510/dotfiles"
chezmoi --source "$HOME/ghq/github.com/maro114510/dotfiles" init
```

`chezmoi init` prompts for the values below and writes
`~/.config/chezmoi/chezmoi.toml`.

| Prompt | Example | Notes |
|---|---|---|
| Default git email | `you@example.com` | Used as the fallback email in all repos |
| Work project directory | `~/ghq/github.com/yourcompany/` | Leave empty to skip; trailing `/` required |
| Work git email | `you@yourcompany.com` | Leave empty to skip |
| Personal project directory | `~/ghq/github.com/yourhandle/` | Leave empty to skip; trailing `/` required |
| Personal git email | `you@personal.example.com` | Leave empty to skip |

Per-directory email override files (`~/.config/git/config.work`,
`~/.config/git/config.personal`) are created automatically on first run if you
provide the corresponding email. These files are **not** tracked by chezmoi —
edit them directly if you need to change the email later.

Apply the managed files:

```bash
chezmoi apply
```

The first apply also runs the one-time scripts that set macOS defaults, create
the local git email files, and set up the Raycast memo-search extension. The
Raycast setup reports an error until Bun is installed in step 4. chezmoi keeps
a failed `run_once` script pending and retries it on the next `chezmoi apply`
(step 7).

Check that the source path matches the clone location:

```bash
chezmoi source-path   # $HOME/ghq/github.com/maro114510/dotfiles
```

To add a new directory context in the future:

```bash
chezmoi edit ~/.config/git/config
chezmoi apply
```

### 3. Install Homebrew packages

`chezmoi apply` already runs `brew bundle` when `~/.Brewfile` changes. Run it
explicitly so the step can be checked and repeated:

```bash
brew bundle --file="$HOME/.Brewfile"
```

Check that every entry is present:

```bash
brew bundle check --file="$HOME/.Brewfile"
```

### 4. Install mise-managed tools

Open a new terminal (`exec zsh -l`) so `~/.local/bin` and the mise shims are on
`PATH`, then install the locked tool versions:

```bash
mise install --locked
```

`--locked` takes download URLs from `~/.config/mise/mise.lock` and fails instead
of falling back to the registry when the lockfile has no entry for the current
platform.

Check that nothing is missing:

```bash
mise ls --missing   # no output
```

### 5. Apply the pnpm security policy

```bash
pnpm-policy.sh --apply
```

Check the policy:

```bash
pnpm-policy.sh --check
```

### 6. Authenticate the GitHub CLI

```bash
gh auth login
```

Check:

```bash
gh auth status
```

### 7. Set up the shell, editor, and Raycast

Start a new login shell so sheldon installs the zsh plugins and the mise shims
resolve:

```bash
exec zsh -l
```

Check:

```bash
command -v nvim   # ~/.local/share/mise/shims/nvim
```

Install the Neovim plugins on first launch:

```bash
nvim +'Lazy! sync' +qa
```

Bun is available now, so apply once more to finish the Raycast extension setup
that was left pending in step 2:

```bash
chezmoi apply
```

Check that the dependency install and build ran:

```bash
test -f "$HOME/.raycast/memo-search/raycast-env.d.ts"
```

Finally, register the extension in Raycast: **Raycast → Import Extension →
`~/.raycast/memo-search`**.

### 8. Verify

```bash
chezmoi diff        # no output
chezmoi status      # no output
mise ls --missing   # no output
pnpm-policy.sh --check
gh auth status
```

## Applying changes on another Mac

Fetch `main` in the chezmoi source, review the pending changes, then apply them:

```bash
git -C "$(chezmoi source-path)" fetch origin main
git -C "$(chezmoi source-path)" switch main
git -C "$(chezmoi source-path)" merge --ff-only origin/main
chezmoi diff
chezmoi apply
```

Check that nothing unexpected remains after the apply:

```bash
chezmoi diff   # no output
```
