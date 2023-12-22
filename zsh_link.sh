#!/bin/bash

CURRENT_DIR=$(pwd)

# if .zshrc exists → backup
if [ -f "$HOME/.zshrc" ]; then
	BACKUP="$HOME/.zshrc_$(date +"%Y%m%d_%H%M%S")"
	cp -r"$HOME/.zshrc" "$BACKUP" || { echo ".zshrc backup faild"; exit 1; }
	echo ".zshrc backup done"
else
	ln -s "$CURRENT_DIR/.config/.zshrc" "$HOME/.zshrc" || { echo ".zshrc link faild"; exit 1; }
	echo ".zshrc linked"
fi

