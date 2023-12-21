#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$CURRENT_DIR/.config/wezterm"

WEZTERM_DIR="$HOME/.config/wezterm"

if [ -d "$WEZTERM_DIR" ]; then
	BACKUP_DIR="$HOME/.config/wezterm_backup_$(date +"%Y%m%d_%H%M%S")"
	cp -r "$WEZTERM_DIR"/* "$BACKUP_DIR" || { echo ".wezterm backup faild"; exit 1; }
	echo "wezterm config backup done"
else
	# mkdir -p "$WEZTERM_DIR"
	ln -s "$TARGET_DIR"/ "$HOME/.config/" || { echo ".wezterm link faild"; exit 1; }
	echo "wezterm linked"
fi

