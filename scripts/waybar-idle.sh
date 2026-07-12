#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/waybar.inc"

load_config waybar-idle

STATE_DIR="${IDLE_STATE_DIR:-$(mono_state_home)/idle}"
STATE_FILE="$STATE_DIR/enabled"

enabled() {
	[[ ! -f "$STATE_FILE" || "$(cat "$STATE_FILE" 2>/dev/null || true)" == enabled ]]
}

set_state() {
	mkdir -p "$STATE_DIR"
	printf '%s\n' "$1" >"$STATE_FILE"
}

start_idle() {
	if pgrep -xu "$USER" hypridle >/dev/null 2>&1; then
		return 0
	fi

	if has_cmd hypridle; then
		hypridle >/dev/null 2>&1 &
	fi
}

stop_idle() {
	pkill -xu "$USER" hypridle >/dev/null 2>&1 || true
	if has_cmd hyprctl; then
		hyprctl dispatch dpms on >/dev/null 2>&1 || true
	fi
}

case "${1:-status}" in
toggle)
	if enabled; then
		set_state disabled
		stop_idle
	else
		set_state enabled
		start_idle
	fi
	;;
on | enable)
	set_state enabled
	start_idle
	;;
off | disable)
	set_state disabled
	stop_idle
	;;
status)
	;;
*)
	printf 'Usage: %s {status|toggle|on|off}\n' "$0" >&2
	exit 2
	;;
esac

if enabled; then
	if pgrep -xu "$USER" hypridle >/dev/null 2>&1; then
		waybar_json "󰌾" "Idle lock on: screen locks and display turns off when inactive" "on"
	else
		waybar_json "󰌾 !" "Idle lock enabled, but hypridle is not running" "warn"
	fi
else
	waybar_json "󰌿" "Idle lock off: display will stay awake" "off"
fi
