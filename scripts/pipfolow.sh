#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/hyprland.inc"

load_config pipfolow
need_cmd jq
need_cmd socat

TITLE="${PIP_TITLE:-Picture-in-Picture}"
PID_FILE="${PIP_PID_FILE:-/tmp/pip-tracker.pid}"

last_workspace=""
last_address=""

stop_previous_instance() {
	local old_pid

	[[ -f "$PID_FILE" ]] || return 0

	old_pid="$(<"$PID_FILE")"
	[[ -n "$old_pid" ]] || return 0

	if ps -p "$old_pid" >/dev/null 2>&1; then
		kill "$old_pid" 2>/dev/null || true
	fi
}

write_pid_file() {
	printf '%s\n' $$ >"$PID_FILE"
	trap 'rm -f "$PID_FILE"' EXIT INT TERM
}

window_address() {
	hypr_json clients |
		jq -r --arg title "$TITLE" '.[] | select(.title == $title) | .address' |
		head -n 1
}

move_pip() {
	local address workspace

	address="$(window_address || true)"
	[[ -n "$address" ]] || return 0

	workspace="$(hypr_json activeworkspace | jq -r '.id')"

	if [[ "$workspace" == "$last_workspace" && "$address" == "$last_address" ]]; then
		return 0
	fi

	hypr_dispatch movetoworkspacesilent "$workspace,address:$address" || true

	last_workspace="$workspace"
	last_address="$address"
}

watch_hyprland_events() {
	local line

	socat -U - "UNIX-CONNECT:$(hypr_event_socket)" 2>/dev/null |
		while read -r line; do
			case "$line" in
			workspace* | focusedmon*)
				move_pip
				;;
			esac
		done
}

stop_previous_instance
write_pid_file
notify "PiP Tracker" "Started tracking Picture-in-Picture window"

move_pip

while true; do
	watch_hyprland_events
	sleep 2
done
