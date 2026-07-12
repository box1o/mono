#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config rofi

CONFIG="${ROFI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi}"

if pgrep -x rofi >/dev/null 2>&1; then
	pkill rofi
	exit 0
fi

rofi \
	-show drun \
	-config "$CONFIG" \
	-modi drun \
	-show-icons
