#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/hyprland.inc"

load_config close-hovered-window
need_cmd jq

LOG_FILE="${CLOSE_HOVERED_LOG:-$(mono_cache_home)/hypr/close-hovered-window.log}"

mkdir_parent "$LOG_FILE"

write_log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

window_under_cursor() {
	local cursor="$1"
	local clients="$2"
	local x y

	read -r x y < <(jq -r '[.x, .y] | @tsv' <<<"$cursor")

	jq -r \
		--argjson x "$x" \
		--argjson y "$y" \
		'[
			.[]
			| select(.mapped == true)
			| select(.hidden == false)
			| select(($x >= .at[0]) and ($x < (.at[0] + .size[0])))
			| select(($y >= .at[1]) and ($y < (.at[1] + .size[1])))
		]
		| sort_by(.focusHistoryID // 999999)
		| .[0]
		| if . then [.address, .class, .title] | @tsv else empty end' \
		<<<"$clients"
}

cursor="$(hypr_json cursorpos || true)"
clients="$(hypr_json clients || true)"

[[ -n "$cursor" && -n "$clients" ]] || die "could not read Hyprland state"

target="$(window_under_cursor "$cursor" "$clients")"

if [[ -z "$target" ]]; then
	read -r x y < <(jq -r '[.x, .y] | @tsv' <<<"$cursor")
	write_log "no target at $x,$y"
	notify "Hyprland" "No window under cursor"
	exit 0
fi

IFS=$'\t' read -r address class title <<<"$target"
write_log "closing address=$address class=$class title=$title"

if has_cmd hyprctl && hyprctl dispatch "hl.dsp.window.close(\"address:$address\")" >/dev/null 2>&1; then
	exit 0
fi

hypr_dispatch closewindow "address:$address" || die "could not close hovered window"
