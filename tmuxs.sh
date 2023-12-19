#!/bin/bash

CURRENT_DIR=$(pwd)

# tmux
if [ -f "$HOME/.tmux.conf" ]; then
    BACKUP="$HOME/.tmux.conf_$(date +"%Y%m%d_%H%M%S")"
    cp -r "$HOME/.tmux.conf" "$BACKUP" || { echo "tmux backup faild"; exit 1; }
    echo ".tmux.conf backup done"
else
	ln -sfn "$CURRENT_DIR/.config/.tmux.conf" "$HOME/.tmux.conf" || { echo "tmux link faild"; exit 1; }
	echo ".tmux.conf linked"
fi

# tmux alias
if [ -f "$HOME/.tmux.session.conf" ]; then
	BACKUP="$HOME/.tmux.session.conf_$(date +"%Y%m%d_%H%M%S")"
	cp -r "$HOME/.tmux.session.conf" "$BACKUP" || { echo "tmux session backup faild"; exit 1; }
    echo "tmux session backup done"
else
	ln -s "$CURRENT_DIR/.config/.tmux.session.conf" "$HOME/.tmux.session.conf" || { echo "tmux session link faild"; exit 1; }
	echo "tmux session linked"
fi

