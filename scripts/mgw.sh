#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/devices/devices.conf"

ADB_PORT="5555"
LOCAL_NET="127.10.0"

log() {
  echo "[mgw] $*"
}

error() {
  echo "[mgw][ERROR] $*" >&2
}

usage() {
  cat <<EOF

Usage:
  mgw mgw1
  mgw mgw2
  mgw mgw3
  mgw mgw4
  mgw mgw5
  mgw mgw6
  mgw mgw7

  mgw all
  mgw stop mgw5
  mgw stop all
  mgw hosts
  mgw list
  mgw status
  mgw scrcpy mgw5
  mgw shell mgw5
  mgw login mgw5

After tunnel is started:
  adb connect mgw5
  scrcpy -s mgw5:5555

EOF
}

load_config() {
  log "Loading config: $CONFIG_FILE"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config file not found: $CONFIG_FILE"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  if [[ -z "${SSH_HOST:-}" ]]; then
    error "SSH_HOST is missing in $CONFIG_FILE"
    exit 1
  fi

  local dev
  for dev in 1 2 3 4 5 6 7; do
    local var="MGW${dev}_IP"
    if [[ -z "${!var:-}" ]]; then
      error "$var is missing in $CONFIG_FILE"
      exit 1
    fi
  done

  log "Config loaded"
  log "SSH_HOST=$SSH_HOST"
}

check_commands() {
  local cmd
  for cmd in ssh pgrep getent; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "Missing command: $cmd"
      exit 1
    fi
  done
}

normalize_device() {
  local input="${1,,}"

  case "$input" in
    1|mgw1|mgr1) printf '%s\n' "1" ;;
    2|mgw2|mgr2) printf '%s\n' "2" ;;
    3|mgw3|mgr3) printf '%s\n' "3" ;;
    4|mgw4|mgr4) printf '%s\n' "4" ;;
    5|mgw5|mgr5) printf '%s\n' "5" ;;
    6|mgw6|mgr6) printf '%s\n' "6" ;;
    7|mgw7|mgr7) printf '%s\n' "7" ;;
    *)
      error "Unknown device: $input"
      usage
      exit 1
      ;;
  esac
}

device_name() {
  local dev="$1"
  printf 'mgw%s\n' "$dev"
}

device_alias2() {
  local dev="$1"
  printf 'mgr%s\n' "$dev"
}

remote_ip_for() {
  local dev="$1"
  local var="MGW${dev}_IP"
  printf '%s\n' "${!var}"
}

local_ip_for() {
  local dev="$1"
  printf '%s.%s\n' "$LOCAL_NET" "$dev"
}

ssh_test() {
  log "Testing SSH connection to $SSH_HOST..."

  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_HOST" "echo ssh-ok" >/tmp/mgw_ssh_test.log 2>&1; then
    error "SSH connection failed"
    cat /tmp/mgw_ssh_test.log
    exit 1
  fi

  log "SSH connection OK"
}

ensure_hosts() {
  local missing=0
  local dev

  for dev in 1 2 3 4 5 6 7; do
    if ! getent hosts "mgw${dev}" >/dev/null 2>&1; then
      missing=1
    fi
  done

  if [[ "$missing" -eq 0 ]]; then
    log "/etc/hosts already contains mgw aliases"
    return 0
  fi

  log "Adding mgw aliases to /etc/hosts"
  log "This may ask for sudo password"

  sudo tee -a /etc/hosts >/dev/null <<EOF

# MGW local ADB tunnel aliases
127.10.0.1 mgw1 mgr1
127.10.0.2 mgw2 mgr2
127.10.0.3 mgw3 mgr3
127.10.0.4 mgw4 mgr4
127.10.0.5 mgw5 mgr5
127.10.0.6 mgw6 mgr6
127.10.0.7 mgw7 mgr7
EOF

  log "Aliases added"
}

list_devices() {
  echo
  echo "Device list from config:"
  echo
  printf "%-8s %-8s %-16s %-16s\n" "Name" "Alias" "Remote IP" "Local IP"
  printf "%-8s %-8s %-16s %-16s\n" "----" "-----" "---------" "--------"

  local dev
  for dev in 1 2 3 4 5 6 7; do
    printf "%-8s %-8s %-16s %-16s\n" \
      "$(device_name "$dev")" \
      "$(device_alias2 "$dev")" \
      "$(remote_ip_for "$dev")" \
      "$(local_ip_for "$dev")"
  done

  echo
}

find_adb_tunnel_pids() {
  local local_ip="$1"
  local remote_ip="$2"

  pgrep -f "ssh .*${local_ip}:${ADB_PORT}:${remote_ip}:${ADB_PORT}" || true
}

start_device() {
  local raw_device="$1"
  local dev
  dev="$(normalize_device "$raw_device")"

  ensure_hosts

  local name
  local alias_name
  local remote_ip
  local local_ip

  name="$(device_name "$dev")"
  alias_name="$(device_alias2 "$dev")"
  remote_ip="$(remote_ip_for "$dev")"
  local_ip="$(local_ip_for "$dev")"

  log "Selected: $name"
  log "Remote:   $remote_ip:$ADB_PORT"
  log "Local:    $name:$ADB_PORT"
  log "Alias:    $alias_name:$ADB_PORT"
  log "Bind IP:  $local_ip:$ADB_PORT"

  local pids
  pids="$(find_adb_tunnel_pids "$local_ip" "$remote_ip")"

  if [[ -n "$pids" ]]; then
    log "Tunnel already running: PID(s) $pids"
  else
    ssh_test

    log "Creating SSH tunnel:"
    log "  $local_ip:$ADB_PORT -> $remote_ip:$ADB_PORT"

    ssh -fNT \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -L "${local_ip}:${ADB_PORT}:${remote_ip}:${ADB_PORT}" \
      "$SSH_HOST"

    sleep 1
  fi

  pids="$(find_adb_tunnel_pids "$local_ip" "$remote_ip")"

  if [[ -z "$pids" ]]; then
    error "Tunnel was not found after creating it"
    exit 1
  fi

  log "Tunnel PID(s): $pids"
  log "Ready"

  echo
  echo "Now you can use:"
  echo "  adb connect $name"
  echo "  adb connect $alias_name"
  echo "  scrcpy -s $name:$ADB_PORT"
  echo
}

stop_device() {
  local raw_device="$1"
  local dev
  dev="$(normalize_device "$raw_device")"

  local name
  local alias_name
  local remote_ip
  local local_ip

  name="$(device_name "$dev")"
  alias_name="$(device_alias2 "$dev")"
  remote_ip="$(remote_ip_for "$dev")"
  local_ip="$(local_ip_for "$dev")"

  log "Stopping: $name"

  if command -v adb >/dev/null 2>&1; then
    adb disconnect "$name" >/dev/null 2>&1 || true
    adb disconnect "$alias_name" >/dev/null 2>&1 || true
    adb disconnect "$name:$ADB_PORT" >/dev/null 2>&1 || true
    adb disconnect "$alias_name:$ADB_PORT" >/dev/null 2>&1 || true
  fi

  local pids
  pids="$(find_adb_tunnel_pids "$local_ip" "$remote_ip")"

  if [[ -z "$pids" ]]; then
    log "No tunnel found for $name"
    return 0
  fi

  log "Killing tunnel PID(s): $pids"
  kill $pids || true
}

start_all() {
  local dev
  for dev in 1 2 3 4 5 6 7; do
    echo
    start_device "$dev"
  done
}

stop_all() {
  local dev
  for dev in 1 2 3 4 5 6 7; do
    stop_device "$dev"
  done
}

scrcpy_device() {
  local raw_device="$1"
  local dev
  dev="$(normalize_device "$raw_device")"

  start_device "$dev"

  local name
  name="$(device_name "$dev")"

  if ! command -v scrcpy >/dev/null 2>&1; then
    error "scrcpy not found"
    exit 1
  fi

  scrcpy -s "$name:$ADB_PORT"
}

shell_device() {
  local raw_device="$1"
  local dev
  dev="$(normalize_device "$raw_device")"

  start_device "$dev"

  local name
  name="$(device_name "$dev")"

  if ! command -v adb >/dev/null 2>&1; then
    error "adb not found"
    exit 1
  fi

  adb connect "$name" >/dev/null || true
  adb -s "$name:$ADB_PORT" shell
}

login_device() {
  local raw_device="$1"
  local dev
  dev="$(normalize_device "$raw_device")"

  start_device "$dev"

  local name
  name="$(device_name "$dev")"

  if ! command -v adb >/dev/null 2>&1; then
    error "adb not found"
    exit 1
  fi

  adb connect "$name" >/dev/null || true
  exec adb -s "$name:$ADB_PORT" shell -t \
    'if [ ! -d /mnt/red-line-fs ]; then
       echo "ERROR: /mnt/red-line-fs not found"
       exit 1
     fi
     chroot /mnt/red-line-fs /usr/bin/env -i \
       HOME=/root \
       TERM=xterm \
       PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
       SHELL=/bin/bash \
       /bin/bash -l'
}

status() {
  list_devices

  echo
  log "Hosts:"
  local dev
  for dev in 1 2 3 4 5 6 7; do
    getent hosts "mgw$dev" || true
  done

  echo
  log "Running tunnel processes:"
  pgrep -af "ssh .*127.10.0" || true

  echo
  if command -v adb >/dev/null 2>&1; then
    log "ADB devices:"
    adb devices
  fi
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  load_config
  check_commands

  case "${1,,}" in
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

    all)
      start_all
      ;;

    stop)
      if [[ "${2:-}" == "all" ]]; then
        stop_all
      elif [[ -n "${2:-}" ]]; then
        stop_device "$2"
      else
        error "Usage: mgw stop mgw5"
        exit 1
      fi
      ;;

    scrcpy)
      if [[ -z "${2:-}" ]]; then
        error "Usage: mgw scrcpy mgw5"
        exit 1
      fi
      scrcpy_device "$2"
      ;;

    shell)
      if [[ -z "${2:-}" ]]; then
        error "Usage: mgw shell mgw5"
        exit 1
      fi
      shell_device "$2"
      ;;

    login)
      if [[ -z "${2:-}" ]]; then
        error "Usage: mgw login mgw5"
        exit 1
      fi
      login_device "$2"
      ;;

    1|2|3|4|5|6|7|mgw1|mgw2|mgw3|mgw4|mgw5|mgw6|mgw7|mgr1|mgr2|mgr3|mgr4|mgr5|mgr6|mgr7)
      start_device "$1"
      ;;

    *)
      error "Unknown command/device: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
