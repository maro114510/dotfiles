#!/bin/bash
# Creates the LaunchAgent's log directory, owner-only because the logs carry a login token, before launchd writes to it.
# The service itself is loaded by `dsh-web-supervisor takeover` or at the next login.
set -uo pipefail
state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/dsh-web"
mkdir -p "${state_dir}" 2>/dev/null && chmod 700 "${state_dir}" 2>/dev/null || true
exit 0
