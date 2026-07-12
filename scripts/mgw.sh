#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config mgw

DEFAULT_REMOTE_ADB_PORT="${MGW_ADB_PORT:-5555}"
LOCAL_NET="${MGW_LOCAL_NET:-127.10.0}"
LOCALHOST_PORT_BASE="${MGW_LOCALHOST_PORT_BASE:-5550}"
DEVICES="${MGW_DEVICES:-1 2 3 4 5 6 7 8 9 10 11 12 13 14}"
CHROOT="${MGW_CHROOT:-}"

require_config() {
	local dev ip_var

	[[ -n "${SSH_HOST:-}" ]] || die "SSH_HOST missing in $(mono_config_file mgw)"
	[[ -n "$LOCAL_NET" ]] || die "MGW_LOCAL_NET missing in $(mono_config_file mgw)"

	for dev in $DEVICES; do
		ip_var="MGW${dev}_IP"
		[[ -n "${!ip_var:-}" ]] || die "$ip_var missing in mgw config"
	done
}

normalize_device() {
	local input="${1,,}"

	input="${input#mgw}"
	input="${input#mgr}"

	[[ -n "$input" ]] || die "missing device"
	[[ " $DEVICES " == *" $input "* ]] || die "unknown device: $1"

	printf '%s\n' "$input"
}

device_name() {
	printf 'mgw%s\n' "$1"
}

device_alias() {
	printf 'mgr%s\n' "$1"
}

remote_ip() {
	local var="MGW${1}_IP"
	printf '%s\n' "${!var}"
}

remote_adb_port() {
	local var="MGW${1}_ADB_PORT"
	printf '%s\n' "${!var:-$DEFAULT_REMOTE_ADB_PORT}"
}

local_ip() {
	printf '%s.%s\n' "$LOCAL_NET" "$1"
}

localhost_port() {
	printf '%s\n' "$((LOCALHOST_PORT_BASE + $1))"
}

adb_serial_alias() {
	printf '%s:%s\n' "$(device_alias "$1")" "$(remote_adb_port "$1")"
}

adb_serial_name() {
	printf '%s:%s\n' "$(device_name "$1")" "$(remote_adb_port "$1")"
}

adb_serial_localhost() {
	printf '127.0.0.1:%s\n' "$(localhost_port "$1")"
}

ssh_test() {
	ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_HOST" 'echo ssh-ok' >/dev/null
}

port_test() {
	local host="$1"
	local port="$2"

	timeout 3 bash -c ":</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

remote_port_test() {
	local dev="$1"

	ssh "$SSH_HOST" \
		"timeout 3 bash -c '</dev/tcp/$(remote_ip "$dev")/$(remote_adb_port "$dev")'" \
		>/dev/null 2>&1
}

ensure_hosts() {
	local dev
	local begin="# MGW local ADB tunnel aliases"
	local tmp

	tmp="$(mktemp)"

	sudo awk -v begin="$begin" '
		$0 == begin { skip = 1; next }
		skip && /^127\.10\.0\./ { next }
		{ skip = 0; print }
	' /etc/hosts > "$tmp"

	{
		cat "$tmp"
		printf '\n%s\n' "$begin"
		for dev in $DEVICES; do
			printf '%s %s %s\n' \
				"$(local_ip "$dev")" \
				"$(device_name "$dev")" \
				"$(device_alias "$dev")"
		done
	} | sudo tee /etc/hosts >/dev/null

	rm -f "$tmp"
}

tunnel_patterns() {
	local dev="$1"
	local rip rport lip lport

	rip="$(remote_ip "$dev")"
	rport="$(remote_adb_port "$dev")"
	lip="$(local_ip "$dev")"
	lport="$(localhost_port "$dev")"

	printf '%s\n' "ssh .*${lip}:${rport}:${rip}:${rport}"
	printf '%s\n' "ssh .*127.0.0.1:${lport}:${rip}:${rport}"
	printf '%s\n' "ssh .*${lip}:${DEFAULT_REMOTE_ADB_PORT}:${rip}:${rport}"
	printf '%s\n' "ssh .*127.0.0.1:${lport}:${rip}:${rport}"
	printf '%s\n' "ssh .*127.0.0.1:${lport}:${rip}:${DEFAULT_REMOTE_ADB_PORT}"
}

tunnel_pids() {
	local dev="$1"
	local pattern

	while IFS= read -r pattern; do
		pgrep -f "$pattern" || true
	done < <(tunnel_patterns "$dev")
}

kill_tunnels() {
	local dev="$1"
	local pids

	pids="$(tunnel_pids "$dev" | sort -u || true)"
	[[ -n "$pids" ]] || return 0

	kill_pids "$pids"
}

adb_disconnect_device() {
	local dev="$1"

	has_cmd adb || return 0

	adb disconnect "$(device_alias "$dev"):$(remote_adb_port "$dev")" >/dev/null 2>&1 || true
	adb disconnect "$(device_name "$dev"):$(remote_adb_port "$dev")" >/dev/null 2>&1 || true
	adb disconnect "$(device_alias "$dev"):$DEFAULT_REMOTE_ADB_PORT" >/dev/null 2>&1 || true
	adb disconnect "$(device_name "$dev"):$DEFAULT_REMOTE_ADB_PORT" >/dev/null 2>&1 || true
	adb disconnect "$(adb_serial_localhost "$dev")" >/dev/null 2>&1 || true
}

adb_connect_device() {
	local dev="$1"
	local serial

	has_cmd adb || return 0

	serial="$(adb_serial_localhost "$dev")"

	adb_disconnect_device "$dev"

	adb connect "$serial" || true
	adb reconnect offline >/dev/null 2>&1 || true
}

list_devices() {
	local dev

	printf '%-8s %-8s %-16s %-10s %-18s %-18s\n' \
		Name Alias Remote RemotePort Localhost AliasTunnel

	for dev in $DEVICES; do
		printf '%-8s %-8s %-16s %-10s %-18s %-18s\n' \
			"$(device_name "$dev")" \
			"$(device_alias "$dev")" \
			"$(remote_ip "$dev")" \
			"$(remote_adb_port "$dev")" \
			"127.0.0.1:$(localhost_port "$dev")" \
			"$(local_ip "$dev"):$(remote_adb_port "$dev")"
	done
}

start_device() {
	local dev="$1"
	local rip rport lip lport

	dev="$(normalize_device "$dev")"

	rip="$(remote_ip "$dev")"
	rport="$(remote_adb_port "$dev")"
	lip="$(local_ip "$dev")"
	lport="$(localhost_port "$dev")"

	ensure_hosts
	ssh_test

	if ! remote_port_test "$dev"; then
		die "remote ADB port is closed: ${rip}:${rport}. Set MGW${dev}_ADB_PORT to the active wireless-debugging port."
	fi

	kill_tunnels "$dev"
	sleep 1

	ssh -fNT \
		-o ExitOnForwardFailure=yes \
		-o ServerAliveInterval=30 \
		-o ServerAliveCountMax=3 \
		-L "${lip}:${rport}:${rip}:${rport}" \
		-L "127.0.0.1:${lport}:${rip}:${rport}" \
		"$SSH_HOST"

	sleep 1

	if ! port_test "$lip" "$rport"; then
		die "local alias tunnel is not reachable: ${lip}:${rport}"
	fi

	if ! port_test "127.0.0.1" "$lport"; then
		die "localhost tunnel is not reachable: 127.0.0.1:${lport}"
	fi

	adb_connect_device "$dev"

	ok "ready:"
	ok "  device:      $(device_name "$dev")"
	ok "  remote:      ${rip}:${rport}"
	ok "  alias:       $(device_alias "$dev"):${rport}"
	ok "  localhost:   127.0.0.1:${lport}"
}

stop_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"

	adb_disconnect_device "$dev"
	kill_tunnels "$dev"

	ok "stopped: $(device_name "$dev")"
}

restart_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"

	stop_device "$dev"
	start_device "$dev"
}

start_all() {
	local dev

	for dev in $DEVICES; do
		start_device "$dev"
	done
}

stop_all() {
	local dev

	for dev in $DEVICES; do
		stop_device "$dev"
	done
}

restart_all() {
	local dev

	for dev in $DEVICES; do
		restart_device "$dev"
	done
}

scrcpy_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"
	start_device "$dev"

	need_cmd scrcpy
	scrcpy -s "$(adb_serial_localhost "$dev")"
}

shell_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"
	start_device "$dev"

	need_cmd adb
	adb -s "$(adb_serial_localhost "$dev")" shell
}

login_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"
	start_device "$dev"

	need_cmd adb
	[[ -n "$CHROOT" ]] || die "MGW_CHROOT missing in $(mono_config_file mgw)"

	exec adb -s "$(adb_serial_localhost "$dev")" shell -t \
		"chroot $CHROOT /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin SHELL=/bin/bash /bin/bash -l"
}

status() {
	list_devices

	printf '\nSSH tunnels:\n'
	pgrep -af "ssh .*${LOCAL_NET}" || true
	pgrep -af "ssh .*127.0.0.1:" || true

	if has_cmd adb; then
		printf '\nADB devices:\n'
		adb devices
	fi
}

check_device() {
	local dev="$1"

	dev="$(normalize_device "$dev")"

	printf 'Checking %s\n' "$(device_name "$dev")"
	printf 'Remote: %s:%s\n' "$(remote_ip "$dev")" "$(remote_adb_port "$dev")"

	if remote_port_test "$dev"; then
		ok "remote ADB port open"
	else
		die "remote ADB port closed: $(remote_ip "$dev"):$(remote_adb_port "$dev")"
	fi
}

usage() {
	cat <<EOF
Usage:
  mgw <mgwN|mgrN|N>          Start one device
  mgw stop <mgwN|mgrN|N>     Stop one device
  mgw restart <mgwN|N>       Restart one device
  mgw check <mgwN|N>         Check remote ADB port from SSH host
  mgw all                    Start all devices
  mgw stop all               Stop all devices
  mgw restart all            Restart all devices
  mgw hosts                  Rewrite /etc/hosts aliases
  mgw list                   List configured devices
  mgw status                 Show tunnels and adb devices
  mgw shell <mgwN|N>         Open adb shell
  mgw login <mgwN|N>         Login via chroot
  mgw scrcpy <mgwN|N>        Open scrcpy

Config supports per-device remote ADB ports:
  MGW8_ADB_PORT="37861"
EOF
}

main() {
	require_config

	case "${1:-}" in
	hosts)
		ensure_hosts
		list_devices
		;;
	list)
		list_devices
		;;
	status)
		status
		;;
	check)
		[[ -n "${2:-}" ]] || die "missing device: mgw check <mgwN|N>"
		check_device "$2"
		;;
	all)
		start_all
		;;
	stop)
		if [[ "${2:-}" == all ]]; then
			stop_all
		else
			[[ -n "${2:-}" ]] || die "missing device: mgw stop <mgwN|N>"
			stop_device "$2"
		fi
		;;
	restart)
		if [[ "${2:-}" == all ]]; then
			restart_all
		else
			[[ -n "${2:-}" ]] || die "missing device: mgw restart <mgwN|N>"
			restart_device "$2"
		fi
		;;
	scrcpy)
		[[ -n "${2:-}" ]] || die "missing device: mgw scrcpy <mgwN|N>"
		scrcpy_device "$2"
		;;
	shell)
		[[ -n "${2:-}" ]] || die "missing device: mgw shell <mgwN|N>"
		shell_device "$2"
		;;
	login)
		[[ -n "${2:-}" ]] || die "missing device: mgw login <mgwN|N>"
		login_device "$2"
		;;
	-h | --help | help | '')
		usage
		;;
	*)
		start_device "$1"
		;;
	esac
}

main "$@"
