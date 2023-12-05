#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$CURRENT_DIR/.config/wezterm"

WEZTERM="$HOME/.wezterm.lua"
WEZTERM_DIR="$HOME/.config/wezterm/config"

if [ -f $WEZTERM ]; then
    BACKUP_FILE="$HOME/.wezterm.lua_backup_$(date +"%Y%m%d_%H%M%S")"
	rsync -oL "$WEZTERM" "$BACKUP_FILE"
	echo ".wezterm.lua backuped"
else
	ln -sfn "$TARGET_DIR/.wezterm.lua" "$WEZTERM"
	echo ".wezterm.lua linked"
fi

if [ -d "$WEZTERM_DIR" ]; then
	BACKUP_DIR="$HOME/.config/wezterm/config_backup_$(date +"%Y%m%d_%H%M%S")"
	rsync -a "$WEZTERM_DIR" "$BACKUP_DIR"
	echo "wezterm config backup done"
else
	mkdir -p "$WEZTERM_DIR"
	for item in "$TARGET_DIR"/*; do
		if [ -e "$item" ]; then
			ln -sfn "$item" "$WEZTERM_DIR/$(basename "$item")"
		fi
	done
	echo "wezterm linked"
fi

