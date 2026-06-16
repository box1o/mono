#!/usr/bin/env bash
set -euo pipefail

PROFILE_MUSIC="a2dp-sink"
PROFILE_MEETING="headset-head-unit"

bt_card() {
	pactl list cards short | awk '/bluez_card\./ {print $2; exit}'
}

active_profile() {
	local card="$1"
	pactl list cards | awk -v card="$card" '
		$0 ~ "Name: " card {found=1}
		found && /^[[:space:]]Active Profile:/ {print $3; exit}
	'
}

is_music_profile() {
	case "$1" in
		a2dp-* | "$PROFILE_MUSIC") return 0 ;;
		*) return 1 ;;
	esac
}

is_meeting_profile() {
	case "$1" in
		headset-* | "$PROFILE_MEETING") return 0 ;;
		*) return 1 ;;
	esac
}

set_profile() {
	local card="$1" profile="$2"
	pactl set-card-profile "$card" "$profile"
	sleep 0.2
	local sink
	sink="$(pactl list sinks short | awk '/bluez_output\./ {print $2; exit}')"
	[[ -n "$sink" ]] && pactl set-default-sink "$sink"
}

json_line() {
	local text="$1" tooltip="$2" class="$3"
	printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
}

print_status() {
	local card active
	card="$(bt_card || true)"
	if [[ -z "$card" ]]; then
		json_line "" "No Bluetooth headset" "off"
		return
	fi
	active="$(active_profile "$card")"
	if is_music_profile "$active"; then
		json_line "󰋋 AAC" "A2DP music - click for MSBC meeting" "a2dp"
	elif is_meeting_profile "$active"; then
		json_line "󰋎 MSBC" "HFP meeting - click for AAC music" "hfp"
	else
		json_line "󰂯 BT" "Profile: ${active} - click to toggle" "other"
	fi
}

toggle_profile() {
	local card active
	card="$(bt_card || true)"
	[[ -n "$card" ]] || return 0
	active="$(active_profile "$card")"
	if is_music_profile "$active"; then
		set_profile "$card" "$PROFILE_MEETING"
	else
		set_profile "$card" "$PROFILE_MUSIC"
	fi
}

case "${1:-status}" in
toggle) toggle_profile ;;
*) print_status ;;
esac
