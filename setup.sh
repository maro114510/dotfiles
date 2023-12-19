#!/bin/bash

set -eu

CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$CURRENT_DIR/scripts"

if ! type -p git >/dev/null; then
  echo "error: git not found on the system" >&2
  exit 1
fi

function script_run {
	if [[ ! -f "$1" ]]; then
		echo "$1 does not exist."
		exit 1
	fi

	sh -c "$1"
}

function link_dotfiles {
	echo "[ Link dotfiles ]"

}
