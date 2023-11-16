#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$CURRENT_DIR/.config/nvim"

NVIM_DIR="$HOME/.config/nvim"

if [ -d "$NVIM_DIR" ]; then
    BACKUP_DIR="$HOME/.config/nvim_backup_$(date +"%Y%m%d_%H%M%S")"
    mv "$NVIM_DIR" "$BACKUP_DIR"
    echo "backup done"
fi

mkdir -p "$NVIM_DIR"

for item in "$TARGET_DIR"/*; do
    if [ -e "$item" ]; then
        ln -sfn "$item" "$NVIM_DIR/$(basename "$item")"
    fi
done

# vim link
ln -sfn "$CURRENT_DIR/.vimrc" "$HOME/.vimrc"

echo "linked"
