#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$CURRENT_DIR/.config/nvim"
NVIM_DIR="$HOME/.config/nvim"

# neovim link
if [ -d "$NVIM_DIR" ]; then
    BACKUP_DIR="$HOME/.config/nvim/nvim_backup_$(date +"%Y%m%d_%H%M%S")"
    rsync -a "$NVIM_DIR" "$BACKUP_DIR"
    echo "nvim backup done"
else
	mkdir -p "$NVIM_DIR"
	for item in "$TARGET_DIR"/*; do
		if [ -e "$item" ]; then
			ln -sfn "$item" "$NVIM_DIR/$(basename "$item")"
		fi
	done
	echo "nvim linked"
fi

# vim link
if [ -f "$CURRENT_DIR/.vimrc" ]; then
    BACKUP_FILE="$HOME/.vimrc_backup_$(date +"%Y%m%d_%H%M%S")"
	rsync -oL "$HOME/.vimrc" "$BACKUP_FILE"
	echo ".vimrc backup done"
else
	ln -sfn "$CURRENT_DIR/.vimrc" "$HOME/.vimrc"
	echo ".vimrc linked"
fi

