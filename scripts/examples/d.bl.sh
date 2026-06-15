#!/usr/bin/env bash
# MOCK adb-tunnel d.bl.sh — same commands as repo/ug/adb-tunnel, logs only.
# Safe for testing mono `d`. Does not run ssh, adb, curl, or network I/O.

DIR=$(pwd)
REPO="$DIR"

. $(gbl log)
. $(gbl d_lib docs)

error_trap

TARGET_FILE=".example_mgw_target"
PID_FILE=".example_adb_tunnel.pid"
SSH_JUMP_HOST="beast-main"
REMOTE_ADB_PORT="5555"

declare -A MGW_IPS=(
	[MGW-2]="222.222.222.154"
	[MGW-3]="222.222.222.232"
	[MGW-4]="222.222.222.251"
	[MGW-5]="222.222.222.204"
	[MGW-6]="222.222.222.71"
	[MGW-7]="222.222.222.69"
)

declare -A MGW_PORTS=(
	[MGW-2]="15652"
	[MGW-3]="15653"
	[MGW-4]="15654"
	[MGW-5]="15655"
	[MGW-6]="15656"
	[MGW-7]="15657"
)

_mock() {
	log "[MOCK] $*"
}

_require_target() {
	[ -f "$TARGET_FILE" ] || fatal "No target selected. Run: d set_target_mgw MGW-7"
	# shellcheck source=/dev/null
	. "$TARGET_FILE"
}

_local_adb_serial() {
	echo "127.0.0.1:$MGW_PORT"
}

_tunnel_is_running() {
	[ -f "$PID_FILE" ] || return 1
	local pid
	pid="$(cat "$PID_FILE")"
	[[ "$pid" == mock-* ]]
}

gblcmd_descr_list_mgw="List available MGW devices"
gblcmd_list_mgw() {
	for mgw in "${!MGW_IPS[@]}"; do
		echo "$mgw -> ${MGW_IPS[$mgw]} local:${MGW_PORTS[$mgw]}"
	done | sort
}

gblcmd_descr_set_target_mgw="Set target MGW, example: d set_target_mgw MGW-7"
gblcmd_set_target_mgw() {
	local mgw="$1"

	[ -n "$mgw" ] || fatal "Usage: d set_target_mgw MGW-7"
	[ -n "${MGW_IPS[$mgw]}" ] || fatal "Unknown MGW: $mgw. Run: d list_mgw"

	cat >"$TARGET_FILE" <<EOF
MGW_NAME="$mgw"
MGW_IP="${MGW_IPS[$mgw]}"
MGW_PORT="${MGW_PORTS[$mgw]}"
EOF

	_mock "set_target_mgw $mgw (wrote $TARGET_FILE)"
	cat "$TARGET_FILE"
}

gblcmd_descr_show_target_mgw="Show selected MGW target"
gblcmd_show_target_mgw() {
	_require_target
	echo "MGW_NAME=$MGW_NAME"
	echo "MGW_IP=$MGW_IP"
	echo "MGW_PORT=$MGW_PORT"
	echo "ADB_SERIAL=$(_local_adb_serial)"
}

gblcmd_descr_check_target="Check selected MGW ADB port from BEAST"
gblcmd_check_target() {
	_require_target
	_mock "ssh $SSH_JUMP_HOST nc -vz $MGW_IP $REMOTE_ADB_PORT"
}

gblcmd_descr_tunnel_start="Start background SSH tunnel to selected MGW ADB"
gblcmd_tunnel_start() {
	_require_target

	if _tunnel_is_running; then
		_mock "tunnel already running PID=$(cat "$PID_FILE") ADB=$(_local_adb_serial)"
		return 0
	fi

	rm -f "$PID_FILE"
	_mock "ssh -f -N -L $MGW_PORT:$MGW_IP:$REMOTE_ADB_PORT $SSH_JUMP_HOST"
	echo "mock-$$" >"$PID_FILE"
	_mock "adb connect $(_local_adb_serial)"
	_mock "adb devices"
}

gblcmd_descr_tunnel_stop="Stop background SSH tunnel"
gblcmd_tunnel_stop() {
	if [ ! -f "$PID_FILE" ]; then
		_mock "tunnel_stop: no PID file"
		return 0
	fi
	_mock "kill tunnel PID=$(cat "$PID_FILE")"
	rm -f "$PID_FILE"
}

gblcmd_descr_tunnel_status="Show background SSH tunnel status"
gblcmd_tunnel_status() {
	_require_target
	if _tunnel_is_running; then
		_mock "tunnel running PID=$(cat "$PID_FILE") ADB=$(_local_adb_serial)"
	else
		_mock "tunnel not running"
	fi
	_mock "adb devices"
}

gblcmd_descr_tunnel_restart="Restart background SSH tunnel"
gblcmd_tunnel_restart() {
	_mock "tunnel_restart"
	gblcmd_tunnel_stop
	gblcmd_tunnel_start
}

gblcmd_descr_adb_connect="Connect adb to selected MGW through local tunnel"
gblcmd_adb_connect() {
	_require_target
	_mock "adb connect $(_local_adb_serial)"
	_mock "adb devices"
}

gblcmd_descr_adb_disconnect="Disconnect adb from selected MGW local tunnel"
gblcmd_adb_disconnect() {
	_require_target
	_mock "adb disconnect $(_local_adb_serial)"
}

gblcmd_descr_adb_deviceid="Show Gateway DeviceID"
gblcmd_adb_deviceid() {
	_require_target
	_mock "adb -s $(_local_adb_serial) shell ... read GatewayConfig.json DeviceID"
	echo "MOCK-DEVICE-ID-0001"
}

gblcmd_descr_adb_root="Restart adb as root for selected MGW"
gblcmd_adb_root() {
	_require_target
	_mock "adb -s $(_local_adb_serial) root"
	_mock "adb -s $(_local_adb_serial) shell id"
	echo "uid=0(root) gid=0(root) groups=0(root) [MOCK]"
}

gblcmd_descr_adb_shell="Open adb shell on selected MGW"
gblcmd_adb_shell() {
	_require_target
	_mock "adb -s $(_local_adb_serial) shell (interactive — not run in mock)"
}

gblcmd_descr_adb_gateway_status="Show PX gateway status inside RedLine rootfs"
gblcmd_adb_gateway_status() {
	_require_target
	_mock "adb -s $(_local_adb_serial) shell chroot ... px status"
	echo "px status: MOCK running"
}

gblcmd_descr_adb_login="Open rootfs shell inside RedLine chroot"
gblcmd_adb_login() {
	_require_target
	_mock "adb -s $(_local_adb_serial) shell chroot /mnt/red-line-fs bash -l (not run in mock)"
}

gblcmd_descr_adb_remount="Run adb remount on selected MGW"
gblcmd_adb_remount() {
	_require_target
	_mock "adb -s $(_local_adb_serial) remount"
}

gblcmd_descr_adb_reboot="Reboot selected MGW"
gblcmd_adb_reboot() {
	_require_target
	_mock "adb -s $(_local_adb_serial) reboot"
	_mock "adb disconnect $(_local_adb_serial)"
	log "Reboot command sent. [MOCK]"
	log "Use this after reboot starts:"
	log "  d adb_wait"
}

gblcmd_descr_adb_wait="Wait until device comes back online and recover ADB 5555 if needed"
gblcmd_adb_wait() {
	_require_target
	local timeout_sec="${1:-300}"
	_mock "adb_wait: would poll up to ${timeout_sec}s, ssh $SSH_JUMP_HOST, tunnel stop/start, adb reconnect"
	_mock "adb_wait: complete (mock — no wait loop)"
}

gblcmd_descr_adb_status="Show adb status for selected MGW"
gblcmd_adb_status() {
	_require_target
	local serial
	serial="$(_local_adb_serial)"
	_mock "adb devices"
	echo ""
	echo "Target: $MGW_NAME"
	echo "ADB:    $serial"
	echo ""
	echo "ro.product.model=MOCK-MGW"
	echo "ro.serialno=MOCK-SERIAL"
	echo "uid=2000(shell) [MOCK]"
}

gblcmd_descr_clean_mock="Remove mock state files in this directory"
gblcmd_clean_mock() {
	rm -f "$TARGET_FILE" "$PID_FILE"
	_mock "removed $TARGET_FILE and $PID_FILE"
}
