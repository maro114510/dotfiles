# dotfiles

Personal macOS development environment configuration files managed with chezmoi.

## Prerequisites

- macOS
- Homebrew package manager
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

## Setup

```bash
# Install chezmoi
brew install chezmoi

# Initialize and apply dotfiles
chezmoi init --apply https://github.com/maro114510/dotfiles.git
```

During initialization, chezmoi will interactively ask for:

| Prompt | Example | Notes |
|---|---|---|
| Default git email | `you@example.com` | Used as the fallback email in all repos |
| Work project directory | `~/ghq/github.com/yourcompany/` | Leave empty to skip; trailing `/` required |
| Work git email | `you@yourcompany.com` | Leave empty to skip |
| Personal project directory | `~/ghq/github.com/yourhandle/` | Leave empty to skip; trailing `/` required |
| Personal git email | `you@personal.example.com` | Leave empty to skip |

Per-directory email override files (`~/.config/git/config.work`, `~/.config/git/config.personal`) are created automatically on first run if you provide the corresponding email. These files are **not** tracked by chezmoi — edit them directly if you need to change the email later.

To add a new directory context in the future:
```bash
chezmoi edit ~/.config/git/config
chezmoi apply
```
