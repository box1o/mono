#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config power-profile
need_cmd powerprofilesctl

current="$(powerprofilesctl get 2>/dev/null || printf balanced)"

case "$current" in
performance)
	next=balanced
	;;
balanced)
	next=power-saver
	;;
power-saver)
	next=performance
	;;
*)
	next=balanced
	;;
esac

powerprofilesctl set "$next"
notify "Power profile" "$next"
