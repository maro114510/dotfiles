#!/bin/bash

CURRENT_DIR=$(pwd)

if [ -f "$HOME/.zshrc" ]; then
    BACKUP="$HOME/.zshrc_$(date +"%Y%m%d_%H%M%S")"
    rsync -oL "$HOME/.zshrc" "$BACKUP"
    echo ".zshrc backup done"
else
	ln -sfn "$CURRENT_DIR/.config/.zshrc" "$HOME/.zshrc"
	echo ".zshrc linked"
fi

