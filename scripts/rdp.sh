#!/usr/bin/env bash
set -euo pipefail

# Load config from ~/.config/rdp/rdp.conf
CONFIG_FILE="$HOME/.config/rdp/rdp.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  echo "Create it with your credentials:"
  echo "  SSH_HOST, RDP_USER, RDP_PASSWORD, VM_IP_1, VM_IP_2, VM_IP_3"
  exit 1
fi
source "$CONFIG_FILE"

SHARED_DIR="$HOME/work"
SHARED_NAME="work"

declare -A VM_IPS=(
  [1]="$VM_IP_1"
  [2]="$VM_IP_2"
  [3]="$VM_IP_3"
)

declare -A VM_NAMES=(
  [1]="Beast-WIN11"
  [2]="Beast-WIN11-3"
  [3]="Beast-WIN11-4"
)

usage() {
  echo "Usage: rdp <machine>"
  echo
  echo "Available machines:"
  echo "  1  Beast-WIN11"
  echo "  2  Beast-WIN11-3"
  echo "  3  Beast-WIN11-4"
}

find_freerdp_client() {
  for cmd in xfreerdp3 xfreerdp wlfreerdp sdl-freerdp; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

ensure_password_file() {
  # Password is now sourced from ~/.config/rdp/rdp.conf
  # No need to create separate password file
  if [[ -z "$RDP_PASSWORD" ]]; then
    echo "ERROR: RDP_PASSWORD not set in config file: $CONFIG_FILE"
    exit 1
  fi
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

VM="$1"

if [[ -z "${VM_IPS[$VM]:-}" ]]; then
  echo "Unknown or disabled machine: $VM"
  echo
  usage
  exit 1
fi

ensure_password_file

RDP_CLIENT="$(find_freerdp_client || true)"

if [[ -z "$RDP_CLIENT" ]]; then
  echo "FreeRDP client not found."
  echo "Install it with:"
  echo "  sudo apt install freerdp3-x11"
  exit 1
fi

REMOTE_IP="${VM_IPS[$VM]}"
VM_NAME="${VM_NAMES[$VM]}"
LOCAL_PORT="339${VM}"

echo "Selected $VM_NAME"
echo "Remote: $REMOTE_IP:3389"
echo "Local:  127.0.0.1:$LOCAL_PORT"
echo "Client: $RDP_CLIENT"

STALE_PIDS="$(pgrep -f "ssh .*127.0.0.1:${LOCAL_PORT}:" || true)"

if [[ -n "$STALE_PIDS" ]]; then
  echo "Killing stale tunnel on 127.0.0.1:$LOCAL_PORT"
  kill $STALE_PIDS || true
  sleep 1
fi

echo "Creating tunnel for $VM_NAME..."
ssh -fnNT \
  -L "127.0.0.1:${LOCAL_PORT}:${REMOTE_IP}:3389" \
  "$SSH_HOST"

echo "Launching RDP for $VM_NAME on 127.0.0.1:$LOCAL_PORT"

"$RDP_CLIENT" \
  /v:127.0.0.1:"$LOCAL_PORT" \
  /u:"$RDP_USER" \
  /p:"$RDP_PASSWORD" \
  /w:1920 \
  /h:1440 \
  /drive:"$SHARED_NAME","$SHARED_DIR" \
  +clipboard \
  +fonts
