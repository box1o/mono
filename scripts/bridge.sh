#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
RELAY_PORT=55092
CHROOT="/mnt/red-line-fs"
PHONE_TMP="/data/local/tmp/fmc_bridge"
ROOTFS_SCRIPT="/tmp/fmc_bridge/listen.py"

log() { echo "[bridge] $*"; }
error() { echo "[bridge][ERROR] $*" >&2; }

usage() {
	cat <<EOF
Usage:
  bridge.sh relay <adb-host> [container]
  bridge.sh listen <adb-host>

  adb-host: mgw2 or mgw2:5555 (after: mgw mgw2)
  container: first running docker name matching ug-dev-v50* (relay only)

  relay: container :55092 -> phone (mgr_sim / gateway PUB)
  listen: phone :55082 system (local) + :55092 sent (relay or local gw)
EOF
}

adb_serial() {
	local host="${1,,}"
	if [[ "$host" == *:* ]]; then
		echo "$host"
	else
		echo "${host}:5555"
	fi
}

adb_connect() {
	local host="${1,,}"
	local name="${host%%:*}"
	adb connect "$name" >/dev/null 2>&1 || true
}

default_container() {
	docker ps --format '{{.Names}}' | grep -E '^ug-dev-v50' | head -1
}

cmd_relay() {
	local adb_host="${1:-}"
	local container="${2:-$(default_container)}"
	local serial cip socat_pid=""

	[[ -n "$adb_host" ]] || {
		error "Usage: bridge.sh relay <adb-host> [container]"
		exit 1
	}
	[[ -n "$container" ]] || {
		error "No running container matching ug-dev-v50*"
		exit 1
	}
	command -v docker >/dev/null || {
		error "docker not found"
		exit 1
	}
	command -v socat >/dev/null || {
		error "socat not found"
		exit 1
	}
	command -v adb >/dev/null || {
		error "adb not found"
		exit 1
	}

	serial="$(adb_serial "$adb_host")"
	adb_connect "$adb_host"

	cip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "$container" | sed -n '/./{p;q;}')"
	[[ -n "$cip" ]] || {
		error "Could not get IP for container: $container"
		exit 1
	}

	cleanup() {
		[[ -n "$socat_pid" ]] && kill "$socat_pid" 2>/dev/null || true
		adb -s "$serial" reverse --remove "tcp:${RELAY_PORT}" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT INT TERM

	if ! docker exec "$container" bash -c "ss -ltn 2>/dev/null | grep -q ':${RELAY_PORT} '" 2>/dev/null; then
		log "WARN: nothing on tcp:${RELAY_PORT} in $container yet — start mgr_sim, then run"
	fi

	socat "TCP-LISTEN:${RELAY_PORT},bind=127.0.0.1,reuseaddr,fork" \
		"TCP:${cip}:${RELAY_PORT},connect-timeout=3,retry=10,interval=2" 2>/dev/null &
	socat_pid=$!
	adb -s "$serial" reverse "tcp:${RELAY_PORT}" "tcp:${RELAY_PORT}" >/dev/null 2>&1

	log "relay :${RELAY_PORT}  $container ($cip) -> phone ($serial)"
	log "Ctrl+C to stop"

	wait "$socat_pid"
}

cmd_listen() {
	local adb_host="${1:-}"
	local serial

	[[ -n "$adb_host" ]] || {
		error "Usage: bridge.sh listen <adb-host>"
		exit 1
	}
	command -v adb >/dev/null || {
		error "adb not found"
		exit 1
	}

	serial="$(adb_serial "$adb_host")"
	adb_connect "$adb_host"

	log "ZMQ listener on phone :55082 (system) + :55092 (sent) ($serial)"

	adb -s "$serial" shell "mkdir -p $PHONE_TMP"
	adb -s "$serial" push "$DIR/listen.py" "$PHONE_TMP/listen.py" >/dev/null
	adb -s "$serial" shell "mkdir -p $CHROOT/tmp/fmc_bridge && cp $PHONE_TMP/listen.py $CHROOT$ROOTFS_SCRIPT"

	exec adb -s "$serial" shell -t \
		"chroot $CHROOT /usr/bin/env -i \
		HOME=/root \
		TERM=xterm \
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		/usr/bin/python3 $ROOTFS_SCRIPT 127.0.0.1"
}

main() {
	if [[ $# -lt 1 ]]; then
		usage
		exit 1
	fi

	case "${1,,}" in
		relay)
			shift
			cmd_relay "$@"
			;;
		listen)
			shift
			cmd_listen "$@"
			;;
		*)
			error "Unknown command: $1"
			usage
			exit 1
			;;
	esac
}

main "$@"
