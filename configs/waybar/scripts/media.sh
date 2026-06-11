#!/usr/bin/env bash

set -euo pipefail

if ! command -v playerctl >/dev/null 2>&1; then
  exit 0
fi

player="${1:-playerctld}"
status="$(playerctl -p "$player" status 2>/dev/null || true)"
[[ -n "$status" ]] || exit 0

artist="$(playerctl -p "$player" metadata artist 2>/dev/null || true)"
title="$(playerctl -p "$player" metadata title 2>/dev/null || true)"
source="$(playerctl -p "$player" metadata xesam:url 2>/dev/null || true)"

icon="󰝚"
case "$source" in
  *youtube*|*youtu.be*) icon="󰗃" ;;
  *spotify*) icon="󰓇" ;;
esac

text="$title"
[[ -n "$artist" ]] && text="$artist - $title"
[[ -n "$text" ]] || text="$status"

case "$status" in
  Paused) icon="󰏤" ;;
  Stopped) icon="󰓛" ;;
esac

printf '%s %s\n' "$icon" "$text"
