#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config brightness
need_cmd brightnessctl

STEP_LOW="${BRIGHTNESS_STEP_LOW:-1%}"
STEP="${BRIGHTNESS_STEP:-5%}"
MIN="${BRIGHTNESS_MIN:-1%}"

current_brightness() {
	brightnessctl -m | awk -F, '{ gsub(/%/, "", $4); print $4; exit }'
}

brightness_device() {
	brightnessctl info | awk -F "'" '/Device/ { print $2; exit }'
}

show_brightness() {
	local percent device bar

	percent="$(current_brightness)"
	device="$(brightness_device)"
	bar="$(seq -s . "$((percent / 15))" | sed 's/[0-9]//g')"

	notify \
		-a brightness \
		-r 91190 \
		-t 900 \
		-i display-brightness-symbolic \
		"${percent}${bar}" \
		"${device:-display}"
}

increase_brightness() {
	if [[ "$(current_brightness)" -lt 10 ]]; then
		brightnessctl set "+$STEP_LOW"
	else
		brightnessctl set "+$STEP"
	fi

	show_brightness
}

decrease_brightness() {
	if [[ "$(current_brightness)" -le 1 ]]; then
		brightnessctl set "$MIN"
	else
		brightnessctl set "$STEP-"
	fi

	show_brightness
}

case "${1:-}" in
i | up | increase)
	increase_brightness
	;;
d | down | decrease)
	decrease_brightness
	;;
*)
	printf 'Usage: %s {i|d}\n' "$0" >&2
	exit 1
	;;
esac
