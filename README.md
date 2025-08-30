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
- **Environment Support**: Separate configurations for different machines (MacBook, Mac Mini, work)

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
chezmoi init --apply https://github.com/maro114510/dotfiles.git

# Navigate to home directory and run system configuration
cd ~
chmod +x setup.sh
./setup.sh
```

### Dependencies

Core tools that will be managed automatically:

* **chezmoi** - Dotfiles manager
* **Neovim v0.9.5+** - Text editor with lazy.nvim plugin manager
* **tmux** - Terminal multiplexer  
* **oh-my-zsh** - Zsh framework
* **Modern CLI Tools** - mise, lazygit, yazi, starship, zoxide, fzf

Environment-specific tools will be installed via Brewfiles:
- `mac_book/Brewfile` - Personal MacBook setup
- `mac_mini/Brewfile` - Desktop Mac Mini setup
- `job_macbook/Brewfile` - Work laptop setup

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

## Environment Configuration

This dotfiles setup supports multiple machine configurations:

- **mac_book**: Personal MacBook with full development stack
- **mac_mini**: Desktop setup with performance optimizations  
- **job_macbook**: Work environment with company-specific tools

The appropriate Brewfile will be used based on your `LOCAL_NAME` environment variable.

## Troubleshooting

**Setup script not found**: Ensure you're in the home directory after chezmoi apply
**Permission denied**: Run `chmod +x setup.sh` before execution
**Brew command not found**: Install Homebrew first (see Prerequisites)
**Plugin errors in Neovim**: Run `:Lazy sync` after first Neovim launch

Please contact me if you need anything else.

