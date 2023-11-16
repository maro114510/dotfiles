#!/bin/bash

CURRENT_DIR=$(pwd)

if [ -f "$HOME/.zshrc" ]; then
    BACKUP="$HOME/.zshrc_$(date +"%Y%m%d_%H%M%S")"
    mv "$HOME/.zshrc" "$BACKUP"
    echo "backup done"
fi

ln -sfn "$CURRENT_DIR/.config/.zshrc" "$HOME/.zshrc"

echo "linked"
