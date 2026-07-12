#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/hyprland.inc"

load_config screenshot

SAVE_DIR="${SCREENSHOT_DIR:-${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}}"
MODE="${1:-region}"
EDIT="${SCREENSHOT_EDIT:-0}"

capture_full() {
	grim "$1"
}

capture_region() {
	local geometry

	geometry="$(slurp)" || exit 0
	[[ -n "$geometry" ]] || exit 0

	grim -g "$geometry" "$1"
}

capture_window() {
	local geometry

	need_cmd jq

	geometry="$(hypr_json activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
	[[ "$geometry" != "null,null nullxnull" ]] || die "no active window"

	grim -g "$geometry" "$1"
}

copy_to_clipboard() {
	local file="$1"

	has_cmd wl-copy || return 0
	wl-copy --type image/png <"$file"
}

open_editor() {
	local file="$1"

	[[ "$EDIT" == 1 ]] || return 0
	has_cmd swappy || return 0

	swappy -f "$file"
}

usage() {
	printf 'Usage: %s {d|full|p|region|w|window|edit}\n' "$0" >&2
}

need_cmd grim
mkdir -p "$SAVE_DIR"

file="$SAVE_DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

case "$MODE" in
d | full)
	capture_full "$file"
	;;
p | region)
	need_cmd slurp
	capture_region "$file"
	;;
w | window)
	capture_window "$file"
	;;
edit)
	need_cmd slurp
	EDIT=1
	capture_region "$file"
	;;
*)
	usage
	exit 1
	;;
esac

open_editor "$file"
copy_to_clipboard "$file"
notify "Screenshot saved" "$file"
