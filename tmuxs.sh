#!/bin/bash

CURRENT_DIR=$(pwd)

if [ -f "$HOME/.tmux.conf" ]; then
    BACKUP="$HOME/.tmux.conf_$(date +"%Y%m%d_%H%M%S")"
    mv "$HOME/.tmux.conf" "$BACKUP"
    echo "backup done"
fi

ln -sfn "$CURRENT_DIR/.config/.tmux.conf" "$HOME/.tmux.conf"

if [ -f "$HOME/.tmux.session.conf" ]; then
	BACKUP="$HOME/.tmux.session.conf_$(date +"%Y%m%d_%H%M%S")"
	mv "$HOME/.tmux.session.conf" "$BACKUP"
    echo "backup done"
fi

echo "linked"
