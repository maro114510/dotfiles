#!/bin/bash
# chezmoi run_once_after_ script: apply macOS system preferences

set -euo pipefail

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.Finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Mouse
defaults write com.apple.mouse.doubleClickThreshold -float 0.5
defaults write com.apple.mouse.scaling -int 8
defaults write com.apple.scrollwheel.scaling -int 4
defaults write com.apple.springing.delay -float 0

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 3
defaults write NSGlobalDomain InitialKeyRepeat -int 20

echo "macOS system preferences applied."
