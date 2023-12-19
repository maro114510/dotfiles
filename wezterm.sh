#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$CURRENT_DIR/.config/wezterm"

WEZTERM="$HOME/.wezterm.lua"
WEZTERM_DIR="$HOME/.config/wezterm"

# if .wezterm.lua exists → backup
if [ -f $WEZTERM ]; then
    BACKUP_FILE="$HOME/.wezterm.lua_backup_$(date +"%Y%m%d_%H%M%S")"
	cp -r "$WEZTERM" "$BACKUP_FILE" || { echo "wezterm backup faild"; exit 1; }
	echo ".wezterm.lua backuped"
else
	ln -s "$HOME/.wezterm.lua" "$WEZTERM" || { echo ".wezterm link faild"; exit 1; }
	echo ".wezterm.lua linked"
fi

if [ -d "$WEZTERM_DIR" ]; then
	BACKUP_DIR="$HOME/.config/wezterm/config_backup_$(date +"%Y%m%d_%H%M%S")"
	cp -r "$TARGET_DIR/config" "$WEZTERM_DIR" || { echo ".wezterm backup faild"; exit 1; }
	echo "wezterm config backup done"
else
	mkdir -p "$WEZTERM_DIR"
	ln -s "$WEZTERM_DIR"/* "$WEZTERM_DIR" || { echo ".wezterm link faild"; exit 1; }
	echo "wezterm linked"
fi

