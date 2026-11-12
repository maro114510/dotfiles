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

See [docs/setup.md](docs/setup.md) for the first-time setup procedure.
