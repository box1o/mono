#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

CONFIG_WALLPAPER_DIR="$CONFIG_HOME/hypr/img"
REPO_WALLPAPER_DIR="$REPO_DIR/configs/hypr/img"
CONFIG_THEME="$CONFIG_HOME/rofi/wallpaper.rasi"
REPO_THEME="$REPO_DIR/configs/rofi/wallpaper.rasi"
STATE_FILE="${WALLPAPER_STATE:-$CONFIG_HOME/hypr/current-wallpaper}"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@" >/dev/null 2>&1 || true
  fi
}

die() {
  notify "Wallpaper" "$1"
  printf 'wallpaper-picker: %s\n' "$1" >&2
  exit 1
}

has_wallpapers() {
  [[ -d "$1" ]] || return 1
  find "$1" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
    -print -quit | grep -q .
}

choose_existing_file() {
  local first="$1"
  local second="$2"

  if [[ -f "$first" ]]; then
    printf '%s\n' "$first"
  elif [[ -f "$second" ]]; then
    printf '%s\n' "$second"
  else
    printf '%s\n' "$first"
  fi
}

wallpaper_dir="${WALLPAPER_DIR:-}"
if [[ -z "$wallpaper_dir" ]]; then
  if has_wallpapers "$CONFIG_WALLPAPER_DIR"; then
    wallpaper_dir="$CONFIG_WALLPAPER_DIR"
  elif has_wallpapers "$REPO_WALLPAPER_DIR"; then
    wallpaper_dir="$REPO_WALLPAPER_DIR"
  else
    wallpaper_dir="$CONFIG_WALLPAPER_DIR"
  fi
fi

theme_file="${ROFI_WALLPAPER_THEME:-$(choose_existing_file "$REPO_THEME" "$CONFIG_THEME")}"

stop_wallpaper_daemons() {
  pkill -x hyprpaper 2>/dev/null || true
  pkill -x swww-daemon 2>/dev/null || true
  pkill -x swaybg 2>/dev/null || true
}

apply_wallpaper() {
  local image="$1"

  command -v swaybg >/dev/null 2>&1 || die "swaybg is not installed"
  [[ -f "$image" ]] || die "Wallpaper not found: $image"

  stop_wallpaper_daemons
  nohup swaybg -i "$image" -m fill >/dev/null 2>&1 &
}

save_wallpaper() {
  mkdir -p -- "$(dirname -- "$STATE_FILE")"
  printf '%s\n' "$1" >"$STATE_FILE"
}

restore_wallpaper() {
  local image=""

  if [[ -f "$STATE_FILE" ]]; then
    image="$(<"$STATE_FILE")"
  fi

  if [[ -z "$image" || ! -f "$image" ]]; then
    image="$(find "$wallpaper_dir" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
      -print -quit)"
  fi

  [[ -n "$image" ]] || die "No wallpaper available to restore"
  apply_wallpaper "$image"
}

if [[ "${1:-}" == "--restore" ]]; then
  restore_wallpaper
  exit 0
fi

command -v rofi >/dev/null 2>&1 || die "rofi is not installed"
has_wallpapers "$wallpaper_dir" || die "No wallpapers found in $wallpaper_dir"

mapfile -d '' wallpapers < <(
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
    -print0 | sort -z
)

rofi_rows() {
  local image label

  for image in "${wallpapers[@]}"; do
    label="$(basename -- "$image")"
    label="${label%.*}"
    label="${label//-/ }"
    label="${label//_/ }"
    printf '%s\0icon\x1f%s\n' "$label" "$image"
  done
}

selection="$(
  rofi_rows | rofi \
    -dmenu \
    -i \
    -show-icons \
    -format 'i' \
    -p 'Wallpapers' \
    -theme "$theme_file"
)"

[[ -n "${selection:-}" ]] || exit 0
[[ "$selection" =~ ^[0-9]+$ ]] || exit 0
(( selection >= 0 && selection < ${#wallpapers[@]} )) || die "Invalid wallpaper selection"

target="${wallpapers[$selection]}"

apply_wallpaper "$target"
save_wallpaper "$target"

notify "Wallpaper" "$(basename -- "$target")" -i "$target"
