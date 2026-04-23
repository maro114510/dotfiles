# dotfiles

Personal macOS development environment configuration files managed with chezmoi.

## What's Included

- **Shell Configuration**: Enhanced zsh with oh-my-zsh, custom aliases and functions
- **Text Editor**: Neovim with lazy.nvim plugin manager and optimized configurations
- **Terminal Tools**: tmux multiplexer with custom sessions and key bindings
- **Development Tools**: mise for runtime management, lazygit for Git operations
- **File Management**: yazi terminal file manager with custom themes
- **Shell Enhancements**: starship prompt, zoxide for smart navigation, fzf for fuzzy finding
- **macOS Settings**: System preferences automation via setup script

## Prerequisites

- macOS (tested on recent versions)
- Homebrew package manager
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

## Setup

### New Environment Setup

```bash
# Install chezmoi
brew install chezmoi

# Initialize and apply dotfiles
# You will be prompted for git identity information (see Git Identity below)
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

To add a new directory context in the future, edit the template and add an `includeIf` block:
```bash
chezmoi edit ~/.config/git/config
chezmoi apply
```

### Dependencies

Core tools that will be managed automatically:

* **chezmoi** - Dotfiles manager
* **Neovim v0.9.5+** - Text editor with lazy.nvim plugin manager
* **tmux** - Terminal multiplexer  
* **oh-my-zsh** - Zsh framework
* **Modern CLI Tools** - mise, lazygit, yazi, starship, zoxide, fzf

### Legacy Setup (without chezmoi)

```bash
git clone https://github.com/maro114510/dotfiles.git
cd dotfiles
./setup.sh -s
```

## Features

- **Productivity**: Custom aliases and functions for common development tasks
- **Git Integration**: Enhanced git workflows with lazygit and custom aliases
- **Smart Navigation**: Quick directory jumping with zoxide and fzf integration
- **Visual Enhancement**: Modern terminal UI with starship prompt and yazi file manager
- **Development Ready**: Pre-configured for multiple programming languages via mise
- **Claude Code Ready**: Optimized configurations for AI-assisted development

## Troubleshooting

**Setup script not found**: Ensure you're in the home directory after chezmoi apply
**Permission denied**: Run `chmod +x setup.sh` before execution
**Brew command not found**: Install Homebrew first (see Prerequisites)
**Plugin errors in Neovim**: Run `:Lazy sync` after first Neovim launch

Please contact me if you need anything else.

