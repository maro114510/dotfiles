#!/bin/bash
# Creates the LaunchAgent's log directory before launchd writes to it.
# The service itself is loaded by `dsh-web-supervisor takeover` or at the next login.
set -uo pipefail
mkdir -p "${XDG_STATE_HOME:-${HOME}/.local/state}/dsh-web" 2>/dev/null || true
exit 0
