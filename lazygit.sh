#!/bin/bash

CURRENT_DIR=$(pwd)
TARGET_DIR="$HOME/Library/Application Support/lazygit"

CONFIG="$CURRENT_DIR/.config/lazygit/config.yml"

if [ -f "$TARGET_DIR/config.yml" ]; then
	BACKUP_FILE="$TARGET_DIR/config.$(date +"%Y%m%d_%H%M%S").yml"
	cp -r "$TARGET_DIR/config.yml" "$BACKUP_FILE"
	ln -sfn "$CONFIG" "$TARGET_DIR/config.yml"
	echo "lazygit config backuped"
else
	ln -sfn "$CONFIG" "$TARGET_DIR/config.yml"
	echo "lazygit config linked"
fi

