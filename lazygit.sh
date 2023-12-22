#!/bin/bash

CURRENT_DIR=$(pwd)
LAZY_TARGET_DIR="$HOME/Library/Application Support/lazygit"

LAGY_CONFIG="$CURRENT_DIR/.config/lazygit/config.yml"

if [ -f "$LAZY_TARGET_DIR/config.yml" ]; then
	BACKUP_FILE="$LAZY_TARGET_DIR/config.$(date +"%Y%m%d_%H%M%S").yml"
	cp -r "$LAZY_TARGET_DIR/config.yml" "$BACKUP_FILE" || { echo "lazygit backup faild"; exit 1; }
	echo "lazygit config backuped"
else
	ln -s "$LAGY_CONFIG" "$LAZY_TARGET_DIR/config.yml" || { echo "lazygit link faild"; exit 1; }
	echo "lazygit config linked"
fi

