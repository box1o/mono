#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/waybar.inc"

load_config waybar-battery

BATTERY="${WAYBAR_BATTERY:-BAT1}"
BATTERY_PATH="/sys/class/power_supply/$BATTERY"

read_battery() {
	percent=0
	status=Unknown

	[[ -f "$BATTERY_PATH/capacity" ]] && percent="$(<"$BATTERY_PATH/capacity")"
	[[ -f "$BATTERY_PATH/status" ]] && status="$(<"$BATTERY_PATH/status")"

	[[ "$percent" =~ ^[0-9]+$ ]] || percent=0
}

battery_icon() {
	if ((percent >= 90)); then
		printf '󰁹\n'
	elif ((percent >= 80)); then
		printf '󰂂\n'
	elif ((percent >= 60)); then
		printf '󰂀\n'
	elif ((percent >= 40)); then
		printf '󰁾\n'
	elif ((percent >= 20)); then
		printf '󰁼\n'
	else
		printf '󰁺\n'
	fi
}

battery_class() {
	if ((percent <= 15)); then
		printf 'critical\n'
	elif ((percent <= 30)); then
		printf 'warning\n'
	else
		printf 'normal\n'
	fi
}

read_battery

case "$status" in
Charging)
	icon="󰂄"
	class=charging
	mark=+
	;;
Full | 'Not charging')
	icon="󰁹"
	class=normal
	mark='='
	;;
*)
	icon="$(battery_icon)"
	class="$(battery_class)"
	mark='-'
	;;
esac

waybar_json "$icon $mark$percent%" "$status" "$class"
