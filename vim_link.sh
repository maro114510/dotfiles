#!/bin/bash

CURRENT_DIR=$(pwd)
NVIM_TARGET_DIR="$CURRENT_DIR/.config/nvim"
NVIM_DIR="$HOME/.config/nvim"

# neovim link
if [ -d "$NVIM_DIR" ]; then
    BACKUP_DIR="$HOME/.config/nvim/nvim_backup_$(date +"%Y%m%d_%H%M%S")"
    cp -r "$NVIM_DIR" "$BACKUP_DIR" || { echo "nvim backup faild"; exit 1; }
    echo "nvim backup done"
else
	mkdir -p "$NVIM_DIR"
	ln -s "$NVIM_TARGET_DIR"/* "$NVIM_DIR" || { echo "nvim link faild"; exit 1; }
	echo "nvim linked"
fi

# vim link
if [ -f "$HOME/.vimrc" ]; then
    BACKUP_FILE="$HOME/.vimrc_backup_$(date +"%Y%m%d_%H%M%S")"
	cp -r "$HOME/.vimrc" "$BACKUP_FILE" || { echo "vim backup faild"; exit 1; }
	echo ".vimrc backup done"
else
	touch .vimrc
	ln -s "$CURRENT_DIR/.vimrc" "$HOME/.vimrc" || { echo "vim link faild"; exit 1; }
	echo ".vimrc linked"
fi

