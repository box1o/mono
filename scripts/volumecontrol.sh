#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config volume
need_cmd pactl
need_cmd pamixer

STEP="${VOLUME_STEP:-5}"
MAX="${VOLUME_MAX:-100}"
NOTIFY_ID="${VOLUME_NOTIFY_ID:-9993}"

volume_notify() {
	notify -p -r "$NOTIFY_ID" "Volume" "$1" >/dev/null || true
}

set_volume() {
	local delta="$1"
	local current next

	current="$(pamixer --get-volume)"
	next="$((current + delta))"

	if ((next > MAX)); then
		next="$MAX"
	elif ((next < 0)); then
		next=0
	fi

	pactl set-sink-volume @DEFAULT_SINK@ "$next%"
	volume_notify "Volume: $next%"
}

toggle_mute() {
	pactl set-sink-mute @DEFAULT_SINK@ toggle

	if [[ "$(pamixer --get-mute)" == true ]]; then
		volume_notify "Volume: muted"
	else
		volume_notify "Volume: $(pamixer --get-volume)%"
	fi
}

case "${1:-}" in
i | up | increase)
	set_volume "$STEP"
	;;
d | down | decrease)
	set_volume "-$STEP"
	;;
m | mute | toggle)
	toggle_mute
	;;
*)
	printf 'Usage: %s {i|d|m}\n' "$0" >&2
	exit 1
	;;
esac
