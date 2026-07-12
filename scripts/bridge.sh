#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/adb.inc"
source "$MONO_LIB_DIR/docker.inc"

load_config bridge

RELAY_PORT="${BRIDGE_RELAY_PORT:-55092}"
CONTAINER_PREFIX="${BRIDGE_CONTAINER_PREFIX:-}"
CHROOT="${BRIDGE_CHROOT:-}"
PHONE_TMP="${BRIDGE_PHONE_TMP:-}"
ROOTFS_SCRIPT="${BRIDGE_ROOTFS_SCRIPT:-}"
SERVICE="${BRIDGE_SERVICE:-}"
SERVICE_SRC_DIR="${BRIDGE_SRC_DIR:-}"
SERVICE_LOG_TAG="${BRIDGE_LOG_TAG:-$SERVICE}"
SERVICE_BUILD_SCRIPT="${BRIDGE_BUILD_SCRIPT:-}"

usage() {
	cat <<EOF_USAGE
Usage:
  bridge.sh relay <adb-host> [container]
  bridge.sh listen <adb-host>
  bridge.sh line {full|build|push|start|stop|restart|status|logs|remount} [adb-host] [--dump]
EOF_USAGE
}

is_mgw_serial() {
	[[ "$1" =~ ^(mgw[1-7]|mgr[1-7])(:[0-9]+)?$ ]]
}

pick_serial() {
	local device

	for device in "$@"; do
		if [[ "$device" =~ ^mgr[1-7]: ]]; then
			printf '%s\n' "$device"
			return 0
		fi
	done

	for device in "$@"; do
		if [[ "$device" =~ ^mgw[1-7]: ]]; then
			printf '%s\n' "$device"
			return 0
		fi
	done

	return 1
}

auto_connect_from_mgw_tunnel() {
	local line dev serial

	while read -r line; do
		[[ "$line" =~ 127\.10\.0\.([1-7]):5555 ]] || continue

		dev="${BASH_REMATCH[1]}"
		serial="mgr${dev}:5555"

		adb_connect "mgr$dev"
		sleep .5

		if adb_cmd devices | awk -v s="$serial" '$1 == s && $2 == "device" { found = 1 } END { exit !found }'; then
			printf '%s\n' "$serial"
			return 0
		fi
	done < <(pgrep -af 'ssh .*127\.10\.0\.[1-7]:5555' 2>/dev/null || true)

	return 1
}

resolve_host() {
	local host="${1:-}"
	local serial
	local devices

	if [[ -n "$host" ]]; then
		printf '%s\n' "$host"
		return 0
	fi

	mapfile -t devices < <(adb_cmd devices | awk '$2 == "device" { print $1 }')

	if ((${#devices[@]} == 1)); then
		printf '%s\n' "${devices[0]}"
		return 0
	fi

	if ((${#devices[@]} > 1)); then
		serial="$(pick_serial "${devices[@]}" || true)"
		if [[ -n "$serial" ]]; then
			printf '%s\n' "$serial"
			return 0
		fi
	fi

	auto_connect_from_mgw_tunnel || die "no adb device"
}

require_service_config() {
	[[ -n "$SERVICE" ]] || die "BRIDGE_SERVICE missing in $(mono_config_file bridge)"
	[[ -n "$SERVICE_SRC_DIR" ]] || die "BRIDGE_SRC_DIR missing in $(mono_config_file bridge)"
	[[ -n "$SERVICE_BUILD_SCRIPT" ]] || die "BRIDGE_BUILD_SCRIPT missing in $(mono_config_file bridge)"
	need_dir "$SERVICE_SRC_DIR"
}

require_service_name() {
	[[ -n "$SERVICE" ]] || die "BRIDGE_SERVICE missing in $(mono_config_file bridge)"
}

ensure_vendor_rw() {
	local host="$1"
	local serial remount

	serial="$(adb_serial "$host")"
	adb_with_serial "$host" root >/dev/null

	remount="$(adb_cmd -s "$serial" remount 2>&1 || true)"
	if [[ "$remount" == *'Now reboot your device'* ]]; then
		die "adb remount needs reboot"
	fi

	adb_shell "$host" 'mount -o rw,remount /vendor 2>/dev/null || mount -o rw,remount / 2>/dev/null || true'
	adb_shell "$host" 'touch /vendor/.line-rw-test && rm /vendor/.line-rw-test' >/dev/null || die "/vendor is not writable"
}

wait_service_stopped() {
	local host="$1"
	local status
	local i

	for i in {1..20}; do
		status="$(adb_shell "$host" "getprop init.svc.$SERVICE" 2>/dev/null | tr -d '\r')"
		[[ "$status" != running ]] && return 0
		sleep .5
	done

	adb_shell "$host" "stop $SERVICE; setprop ctl.stop $SERVICE 2>/dev/null || true; killall $SERVICE 2>/dev/null || true"
}

line_build() {
	require_service_config
	need_file "$SERVICE_SRC_DIR/$SERVICE_BUILD_SCRIPT"

	"$SERVICE_SRC_DIR/$SERVICE_BUILD_SCRIPT"
}

line_stop() {
	local host="$1"

	require_service_name
	adb_with_serial "$host" root >/dev/null
	adb_shell "$host" "stop $SERVICE; setprop ctl.stop $SERVICE 2>/dev/null || true"
}

line_start() {
	local host="$1"

	require_service_name
	adb_with_serial "$host" root >/dev/null
	adb_shell "$host" "start $SERVICE"
}

line_push() {
	local host="$1"
	local bin rsu

	require_service_config

	bin="$SERVICE_SRC_DIR/out/$SERVICE"
	rsu="$SERVICE_SRC_DIR/rsu.sh"

	need_file "$bin"

	line_stop "$host"
	wait_service_stopped "$host"
	ensure_vendor_rw "$host"

	adb_with_serial "$host" push "$bin" "/data/local/tmp/$SERVICE"
	adb_shell "$host" "cp /data/local/tmp/$SERVICE /vendor/bin/$SERVICE && chmod 755 /vendor/bin/$SERVICE"

	if [[ -f "$rsu" ]]; then
		adb_with_serial "$host" push "$rsu" /data/local/tmp/rsu.sh
		adb_shell "$host" 'cp /data/local/tmp/rsu.sh /vendor/libexec/rsu.sh && chmod 755 /vendor/libexec/rsu.sh'
	fi

	adb_shell "$host" "restorecon -v /vendor/bin/$SERVICE /vendor/libexec/rsu.sh 2>/dev/null || true"
}

line_status() {
	local host="$1"

	require_service_name
	adb_with_serial "$host" root >/dev/null
	adb_shell "$host" "
		echo init.svc.$SERVICE=\$(getprop init.svc.$SERVICE)
		ls -lZ /vendor/bin/$SERVICE /vendor/libexec/$SERVICE.sh /vendor/libexec/rsu.sh 2>/dev/null || true
		cat /proc/mounts | grep \"$SERVICE\" || true
	"
}

line_logs() {
	local host="$1"
	local mode="${2:-follow}"
	local serial

	require_service_name
	serial="$(adb_serial "$host")"
	adb_with_serial "$host" root >/dev/null

	if [[ "$mode" == dump ]]; then
		adb_cmd -s "$serial" logcat -v time -b main -b system -d -s "${SERVICE_LOG_TAG}:*" | tail -n 100
		return 0
	fi

	adb_cmd -s "$serial" logcat -c >/dev/null 2>&1 || true
	resolve_adb
	exec "$ADB_BIN" -s "$serial" logcat -v time -b main -b system -s "${SERVICE_LOG_TAG}:*"
}

line_full() {
	local host="$1"

	line_stop "$host"
	wait_service_stopped "$host"
	line_build
	line_push "$host"
	line_start "$host"
	sleep 2
	line_logs "$host"
}

line_restart() {
	local host="$1"

	line_stop "$host"
	sleep 1
	line_start "$host"
}

cmd_line_logs() {
	local host=""
	local mode=follow

	if [[ "${1:-}" == --dump ]]; then
		mode=dump
	elif [[ -n "${1:-}" ]]; then
		host="$1"
		[[ "${2:-}" == --dump ]] && mode=dump
	fi

	line_logs "$(resolve_host "$host")" "$mode"
}

cmd_line() {
	local sub="${1:-}"
	local host

	shift || true

	case "$sub" in
	full)
		line_full "$(resolve_host "${1:-}")"
		;;
	build)
		line_build
		;;
	push)
		line_push "$(resolve_host "${1:-}")"
		;;
	start)
		line_start "$(resolve_host "${1:-}")"
		;;
	stop)
		line_stop "$(resolve_host "${1:-}")"
		;;
	restart)
		host="$(resolve_host "${1:-}")"
		line_restart "$host"
		;;
	status)
		line_status "$(resolve_host "${1:-}")"
		;;
	logs)
		cmd_line_logs "$@"
		;;
	remount)
		ensure_vendor_rw "$(resolve_host "${1:-}")"
		;;
	*)
		usage
		exit 1
		;;
	esac
}

relay_cleanup() {
	[[ -n "${relay_pid:-}" ]] && kill "$relay_pid" 2>/dev/null || true
	[[ -n "${relay_serial:-}" ]] && adb_cmd -s "$relay_serial" reverse --remove "tcp:$RELAY_PORT" >/dev/null 2>&1 || true
}

cmd_relay() {
	local host="${1:-}"
	local container="${2:-}"
	local cip

	[[ -n "$host" ]] || die "missing adb host"

	[[ -n "$CONTAINER_PREFIX" ]] || die "BRIDGE_CONTAINER_PREFIX missing in $(mono_config_file bridge)"
	container="${container:-$(default_container "$CONTAINER_PREFIX")}"
	[[ -n "$container" ]] || die "no running container matching $CONTAINER_PREFIX"

	need_cmd docker
	need_cmd socat

	relay_serial="$(adb_serial "$host")"
	adb_connect "$host"

	cip="$(container_ip "$container")"
	[[ -n "$cip" ]] || die "container has no IP"

	relay_pid=""
	trap relay_cleanup EXIT INT TERM

	socat \
		"TCP-LISTEN:${RELAY_PORT},bind=127.0.0.1,reuseaddr,fork" \
		"TCP:${cip}:${RELAY_PORT},connect-timeout=3,retry=10,interval=2" \
		2>/dev/null &
	relay_pid=$!

	adb_cmd -s "$relay_serial" reverse "tcp:$RELAY_PORT" "tcp:$RELAY_PORT" >/dev/null 2>&1

	log "relay :$RELAY_PORT $container -> $relay_serial"
	wait "$relay_pid"
}

cmd_listen() {
	local host="${1:-}"
	local serial

	[[ -n "$host" ]] || die "missing adb host"
	[[ -n "$CHROOT" ]] || die "BRIDGE_CHROOT missing in $(mono_config_file bridge)"
	[[ -n "$PHONE_TMP" ]] || die "BRIDGE_PHONE_TMP missing in $(mono_config_file bridge)"
	[[ -n "$ROOTFS_SCRIPT" ]] || die "BRIDGE_ROOTFS_SCRIPT missing in $(mono_config_file bridge)"

	serial="$(adb_serial "$host")"
	adb_connect "$host"

	adb_cmd -s "$serial" shell "mkdir -p $PHONE_TMP"
	adb_cmd -s "$serial" push "$MONO_SCRIPT_DIR/listen.py" "$PHONE_TMP/listen.py" >/dev/null
	adb_cmd -s "$serial" shell "mkdir -p $(dirname "$CHROOT$ROOTFS_SCRIPT") && cp $PHONE_TMP/listen.py $CHROOT$ROOTFS_SCRIPT"

	resolve_adb
	exec "$ADB_BIN" -s "$serial" shell -t \
		"chroot $CHROOT /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/python3 $ROOTFS_SCRIPT 127.0.0.1"
}

case "${1:-}" in
relay)
	shift
	cmd_relay "$@"
	;;
listen)
	shift
	cmd_listen "$@"
	;;
line)
	shift
	cmd_line "$@"
	;;
-h | --help | help | '')
	usage
	;;
*)
	die "unknown command: $1"
	;;
esac
