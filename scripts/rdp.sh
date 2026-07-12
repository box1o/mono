#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config rdp

usage() {
	printf 'Usage: %s <machine>\n' "$0"
	printf 'Machines: %s\n' "${RDP_MACHINES:-1 2 3}"
}

freerdp_client() {
	need_any_cmd xfreerdp3 xfreerdp wlfreerdp sdl-freerdp
}

require_machine_config() {
	local vm="$1"
	local var_ip="RDP_VM_${vm}_IP"
	local remote="${!var_ip:-}"

	[[ -n "${SSH_HOST:-}" ]] || die "SSH_HOST is missing"
	[[ -n "${RDP_USER:-}" ]] || die "RDP_USER is missing"
	[[ -n "${RDP_PASSWORD:-}" ]] || die "RDP_PASSWORD is missing"
	[[ -n "$remote" ]] || die "missing RDP config for machine $vm"
}

machine_ip() {
	local var="RDP_VM_${1}_IP"
	printf '%s\n' "${!var}"
}

machine_name() {
	local vm="$1"
	local var="RDP_VM_${vm}_NAME"
	printf '%s\n' "${!var:-vm-$vm}"
}

stop_existing_tunnel() {
	local port="$1"
	local pids

	pids="$(pgrep -f "ssh .*127.0.0.1:${port}:" || true)"
	kill_pids "$pids"

	[[ -n "$pids" ]] && sleep 1
	return 0
}

start_tunnel() {
	local port="$1"
	local remote="$2"

	log "Starting SSH tunnel 127.0.0.1:${port} -> ${remote}:3389 via ${SSH_HOST}"
	ssh -fnNT -o ExitOnForwardFailure=yes -L "127.0.0.1:${port}:${remote}:3389" "$SSH_HOST"
}

open_rdp() {
	local client="$1"
	local port="$2"
	local shared_dir="${RDP_SHARED_DIR:-$HOME/work}"
	local shared_name="${RDP_SHARED_NAME:-work}"

	"$client" \
		/v:127.0.0.1:"$port" \
		/u:"$RDP_USER" \
		/p:"$RDP_PASSWORD" \
		/w:"${RDP_WIDTH:-1920}" \
		/h:"${RDP_HEIGHT:-1440}" \
		/drive:"$shared_name","$shared_dir" \
		+clipboard \
		+fonts
}

main() {
	local vm="${1:-}"
	local client remote name port

	[[ $# -eq 1 ]] || {
		usage
		exit 1
	}

	require_machine_config "$vm"

	client="$(freerdp_client)"
	remote="$(machine_ip "$vm")"
	name="$(machine_name "$vm")"
	port="${RDP_LOCAL_PORT_PREFIX:-339}$vm"

	stop_existing_tunnel "$port"
	start_tunnel "$port" "$remote"

	log "RDP $name on 127.0.0.1:$port"
	log "Opening $client"
	open_rdp "$client" "$port"
}

main "$@"
