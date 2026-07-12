#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config clipboard
need_cmd cliphist
need_cmd wl-copy
need_cmd rofi

ROFI_THEME="${ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/theme.rasi}"
PROMPT="${CLIPBOARD_PROMPT:-Clipboard}"

selected="$(cliphist list | rofi -dmenu -i -p "$PROMPT" -theme "$ROFI_THEME")"
[[ -n "$selected" ]] || exit 0

printf '%s' "$selected" | cliphist decode | wl-copy
