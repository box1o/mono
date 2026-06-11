#!/usr/bin/env bash

set -euo pipefail

SAVE_DIR="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
MODE="${1:-region}"
EDIT="${SCREENSHOT_EDIT:-0}"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    notify "Screenshot failed" "Missing command: $1"
    exit 1
  fi
}

copy_image() {
  local file="$1"

  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$file"
  fi
}

capture_full() {
  local file="$1"
  grim "$file"
}

capture_region() {
  local file="$1"
  local geometry

  geometry="$(slurp)" || exit 0
  [[ -n "$geometry" ]] || exit 0
  grim -g "$geometry" "$file"
}

capture_active() {
  local file="$1"
  local geometry

  need_cmd jq
  geometry="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
  [[ "$geometry" != "null,null nullxnull" ]] || exit 1
  grim -g "$geometry" "$file"
}

usage() {
  printf 'Usage: %s {d|full|p|region|w|window|edit}\n' "$0"
}

main() {
  need_cmd grim
  mkdir -p "$SAVE_DIR"

  local file="$SAVE_DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

  case "$MODE" in
    d|full) capture_full "$file" ;;
    p|region) capture_region "$file" ;;
    w|window) capture_active "$file" ;;
    edit)
      EDIT=1
      capture_region "$file"
      ;;
    *)
      usage
      exit 1
      ;;
  esac

  if [[ "$EDIT" == 1 ]] && command -v swappy >/dev/null 2>&1; then
    swappy -f "$file"
  fi

  copy_image "$file"
  notify "Screenshot saved" "$file"
}

main "$@"
