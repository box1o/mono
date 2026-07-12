#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

lock_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="$lock_dir/scrcpy-once.lock"

already_running() {
	pgrep -xu "$USER" -x scrcpy >/dev/null 2>&1
}

notify_running() {
	notify "scrcpy" "scrcpy is already running" -t 1500
}

if already_running; then
	notify_running
	exit 0
fi

need_cmd flock
need_cmd scrcpy

exec 9>"$lock_file"

if ! flock -n 9; then
	notify_running
	exit 0
fi

if already_running; then
	notify_running
	exit 0
fi

exec scrcpy "$@"
