#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config waybar

if pgrep -x waybar >/dev/null 2>&1; then
	notify "Waybar" "Restarting Waybar" -t 500
	killall waybar || true
else
	notify "Waybar" "Starting Waybar" -t 500
fi

nohup waybar >/dev/null 2>&1 &
