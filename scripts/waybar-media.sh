#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config waybar-media

has_cmd playerctl || exit 0

player="${1:-${WAYBAR_MEDIA_PLAYER:-playerctld}}"
status="$(playerctl -p "$player" status 2>/dev/null || true)"

[[ -n "$status" ]] || exit 0

artist="$(playerctl -p "$player" metadata artist 2>/dev/null || true)"
title="$(playerctl -p "$player" metadata title 2>/dev/null || true)"
source_url="$(playerctl -p "$player" metadata xesam:url 2>/dev/null || true)"

icon_for_source() {
	case "$source_url" in
	*youtube* | *youtu.be*)
		printf '󰗃\n'
		;;
	*spotify*)
		printf '󰓇\n'
		;;
	*)
		printf '󰝚\n'
		;;
	esac
}

icon="$(icon_for_source)"

case "$status" in
Paused)
	icon="󰏤"
	;;
Stopped)
	icon="󰓛"
	;;
esac

text="$title"
[[ -n "$artist" ]] && text="$artist - $title"
[[ -n "$text" ]] || text="$status"

printf '%s %s\n' "$icon" "$text"
