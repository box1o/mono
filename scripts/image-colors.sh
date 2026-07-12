#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config image-colors

IMG_DIR="${IMAGE_COLORS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/img}"
ROFI_THEME="${ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi}"

need_cmd rofi

load_images() {
	find "$IMG_DIR" -maxdepth 1 -type f \
		\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
		sort
}

choose_image() {
	local image

	for image in "${images[@]}"; do
		printf '%s\0icon\x1f%s\n' "$(basename "$image")" "$image"
	done |
		rofi -dmenu -i -show-icons -p Image -theme "$ROFI_THEME"
}

resolve_image() {
	local chosen="$1"
	local image

	for image in "${images[@]}"; do
		if [[ "$(basename "$image")" == "$chosen" ]]; then
			printf '%s\n' "$image"
			return 0
		fi
	done

	return 1
}

palette_command() {
	local image="$1"
	local cmd

	cmd="$(need_any_cmd magick convert)"

	if [[ "$cmd" == magick ]]; then
		magick "$image" -resize 96x96\! -colors 16 -depth 8 -format %c histogram:info:-
	else
		convert "$image" -resize 96x96\! -colors 16 -depth 8 -format %c histogram:info:-
	fi
}

extract_palette() {
	local image="$1"

	palette_command "$image" |
		sed -nE 's/^[[:space:]]*([0-9]+):.*(#([0-9A-Fa-f]{6})).*/\1 \2/p' |
		sort -nr |
		awk '!seen[$2]++ { printf "%s  <span foreground=\"%s\">████████</span>  %s\n", $2, $2, $1 }' |
		head -n 16
}

choose_color() {
	local palette="$1"

	printf '%s\n' "$palette" |
		rofi -dmenu -i -markup-rows -p Color -theme "$ROFI_THEME" -format s
}

mapfile -t images < <(load_images)
((${#images[@]})) || die "no images in $IMG_DIR"

chosen="$(choose_image)"
[[ -n "$chosen" ]] || exit 0

image="$(resolve_image "$chosen")" || die "image not found"
palette="$(extract_palette "$image")"
selected="$(choose_color "$palette")"

[[ -n "$selected" ]] || exit 0

color="${selected%% *}"
printf '%s' "$color" | copy_text

notify "Image Colors" "Copied $color from $chosen" -i "$image"
