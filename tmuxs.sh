#!/bin/bash

CURRENT_DIR=$(pwd)

# tmux
if [ -f "$HOME/.tmux.conf" ]; then
    BACKUP="$HOME/.tmux.conf_$(date +"%Y%m%d_%H%M%S")"
    rsync -oL "$HOME/.tmux.conf" "$BACKUP"
    echo ".tmux.conf backup done"
else
	ln -sfn "$CURRENT_DIR/.config/.tmux.conf" "$HOME/.tmux.conf"
	echo ".tmux.conf linked"
fi

# tmux alias
if [ -f "$HOME/.tmux.session.conf" ]; then
	BACKUP="$HOME/.tmux.session.conf_$(date +"%Y%m%d_%H%M%S")"
	rsync -oL "$HOME/.tmux.session.conf" "$BACKUP"
    echo "tmux session backup done"
else
	ln -sfn "$CURRENT_DIR/.config/.tmux.session.conf" "$HOME/.tmux.session.conf"
	echo "tmux session linked"
fi

