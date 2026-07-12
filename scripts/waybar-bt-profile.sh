#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/waybar.inc"

load_config waybar-bt-profile

MUSIC="${BT_PROFILE_MUSIC:-a2dp-sink}"
MEETING="${BT_PROFILE_MEETING:-headset-head-unit}"

bt_card() {
	pactl list cards short | awk '/bluez_card\./ { print $2; exit }'
}

active_profile() {
	local card="$1"

	pactl list cards |
		awk -v card="$card" '
			$0 ~ "Name: " card { found = 1 }
			found && /^[[:space:]]Active Profile:/ { print $3; exit }
		'
}

set_profile() {
	local card="$1"
	local profile="$2"
	local sink

	pactl set-card-profile "$card" "$profile"
	sleep .2

	sink="$(pactl list sinks short | awk '/bluez_output\./ { print $2; exit }')"
	[[ -n "$sink" ]] && pactl set-default-sink "$sink"
}

print_status() {
	local card profile

	card="$(bt_card || true)"
	if [[ -z "$card" ]]; then
		waybar_json "" "No Bluetooth headset" off
		return 0
	fi

	profile="$(active_profile "$card")"

	case "$profile" in
	a2dp-* | "$MUSIC")
		waybar_json "󰋋 AAC" "A2DP music - click for MSBC meeting" a2dp
		;;
	headset-* | "$MEETING")
		waybar_json "󰋎 MSBC" "HFP meeting - click for AAC music" hfp
		;;
	*)
		waybar_json "󰂯 BT" "Profile: $profile" other
		;;
	esac
}

toggle_profile() {
	local card profile

	card="$(bt_card || true)"
	[[ -n "$card" ]] || exit 0

	profile="$(active_profile "$card")"

	case "$profile" in
	a2dp-* | "$MUSIC")
		set_profile "$card" "$MEETING"
		;;
	*)
		set_profile "$card" "$MUSIC"
		;;
	esac
}

case "${1:-status}" in
toggle)
	toggle_profile
	;;
*)
	print_status
	;;
esac
