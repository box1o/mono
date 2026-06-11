#!/usr/bin/env bash

set -euo pipefail

IMG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/img"
ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi"

notify_cmd() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

copy_color() {
  local color="$1"
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$color" | wl-copy
  else
    printf '%s\n' "$color"
  fi
}

if ! command -v rofi >/dev/null 2>&1; then
  echo "rofi is required" >&2
  exit 1
fi

mapfile -t images < <(
  find "$IMG_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
)

if [[ ${#images[@]} -eq 0 ]]; then
  notify_cmd "Image Colors" "No images found in $IMG_DIR"
  exit 1
fi

chosen_name=$(
  for image in "${images[@]}"; do
    printf '%s\0icon\x1f%s\n' "$(basename "$image")" "$image"
  done |
  rofi -dmenu -i -show-icons -p "Image" -theme "$ROFI_THEME")
[[ -n "${chosen_name:-}" ]] || exit 0

chosen_image=""
for image in "${images[@]}"; do
  if [[ "$(basename "$image")" == "$chosen_name" ]]; then
    chosen_image="$image"
    break
  fi
done

[[ -n "$chosen_image" ]] || exit 1

if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  notify_cmd "Image Colors" "Install imagemagick to extract palettes"
  exit 1
fi

if command -v magick >/dev/null 2>&1; then
  hist_cmd=(magick "$chosen_image" -resize 96x96\! -colors 16 -depth 8 -format %c histogram:info:-)
else
  hist_cmd=(convert "$chosen_image" -resize 96x96\! -colors 16 -depth 8 -format %c histogram:info:-)
fi

palette="$("${hist_cmd[@]}" |
  sed -nE 's/^[[:space:]]*([0-9]+):.*(#([0-9A-Fa-f]{6})).*/\1 \2/p' |
  sort -nr |
  awk '!seen[$2]++ { printf "%s  <span foreground=\"%s\">████████</span>  %s\n", $2, $2, $1 }' |
  head -n 16)"

[[ -n "$palette" ]] || exit 1

selected=$(printf '%s\n' "$palette" |
  rofi -dmenu -i -markup-rows -p "Color" -theme "$ROFI_THEME" -format s)
[[ -n "${selected:-}" ]] || exit 0

color="${selected%% *}"
copy_color "$color"
notify_cmd "Image Colors" "Copied $color from $chosen_name" -i "$chosen_image"
