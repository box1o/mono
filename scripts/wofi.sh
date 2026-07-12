#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config wofi

CONFIG="${WOFI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/wofi/config/config}"
STYLE="${WOFI_STYLE:-${XDG_CONFIG_HOME:-$HOME/.config}/wofi/colors.css}"

if pgrep -x wofi >/dev/null 2>&1; then
	pkill wofi
	exit 0
fi

wofi \
	--conf "$CONFIG" \
	--style "$STYLE" \
	--show drun
