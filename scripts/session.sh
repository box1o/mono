#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config session

pick_action() {
	printf '%s\n' \
		lock \
		suspend \
		logout \
		reboot \
		shutdown \
		hibernate |
		menu_pick session
}

confirm_power_action() {
	local action="$1"

	case "$action" in
	logout | reboot | shutdown | poweroff)
		printf 'no\nyes\n' | menu_pick "$action?" | grep -Fxq yes
		;;
	*)
		return 0
		;;
	esac
}

lock_session() {
	if has_cmd hyprlock; then
		hyprlock
	else
		loginctl lock-session
	fi
}

run_action() {
	local action="$1"

	case "$action" in
	lock)
		lock_session
		;;
	suspend)
		loginctl lock-session || true
		systemctl suspend
		;;
	logout)
		hyprctl dispatch exit
		;;
	reboot)
		systemctl reboot
		;;
	shutdown | poweroff)
		systemctl poweroff
		;;
	hibernate)
		loginctl lock-session || true
		systemctl hibernate
		;;
	menu)
		action="$(pick_action)"
		[[ -n "$action" ]] || exit 0

		if confirm_power_action "$action"; then
			run_action "$action"
		fi
		;;
	*)
		printf 'Usage: %s {menu|lock|suspend|logout|reboot|shutdown|hibernate}\n' "$0" >&2
		exit 1
		;;
	esac
}

run_action "${1:-menu}"
