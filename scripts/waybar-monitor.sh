#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/waybar.inc"

load_config waybar-monitor

STATE="${MONITOR_STATE:-$(mono_state_home)/monitor/state.json}"

if [[ ! -f "$STATE" ]]; then
	waybar_json " init" "Initializing" monitor-init
	exit 0
fi

state_value() {
	local key="$1"

	python3 -c "import json; print(json.load(open('$STATE')).get('$key',''))" 2>/dev/null || true
}

current_cost() {
	local start hours vm disk

	start="$(state_value start_time)"
	hours="$(python3 -c "print(round(($(date +%s) - ${start:-0}) / 3600.0, 4))")"
	vm="$(python3 -c "print(round($hours * ${VM_COST_PER_HOUR:-0}, 2))")"
	disk="$(python3 -c "print(round(($hours / 730.0) * ${DISK_COST_PER_MONTH:-0}, 2))")"

	python3 -c "print(round($vm + $disk, 2))"
}

total="$(current_cost 2>/dev/null || echo '?')"

if [[ "$(state_value kill_active)" == True ]]; then
	waybar_json " KILL" "LIMIT HIT! \$$total" monitor-kill
elif [[ "$(state_value warn_active)" == True ]]; then
	waybar_json " \$$total" "Warning: \$$total / \$${THRESHOLD_KILL:-?}" monitor-warn
elif systemctl --user is-active monitor.service >/dev/null 2>&1; then
	waybar_json " \$$total" "Azure: \$$total | Limit: \$${THRESHOLD_KILL:-?}" monitor-ok
else
	waybar_json "" "Monitor stopped" monitor-off
fi
