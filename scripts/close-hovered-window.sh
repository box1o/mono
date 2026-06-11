#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/close-hovered-window.log"

mkdir -p -- "$(dirname -- "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@" >/dev/null 2>&1 || true
  fi
}

hypr_json() {
  local command="$1"

  if output="$(hyprctl -j "$command" 2>/dev/null)" && [[ -n "$output" ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket.sock"
  if [[ -S "$socket" ]] && command -v socat >/dev/null 2>&1; then
    printf '/j/%s' "$command" | socat -t 1 - "UNIX-CONNECT:$socket" 2>/dev/null
    return 0
  fi

  return 1
}

hypr_dispatch() {
  local dispatcher="$1"
  local arg="${2:-}"

  if hyprctl dispatch "$dispatcher" "$arg" >/dev/null 2>&1; then
    return 0
  fi

  local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket.sock"
  if [[ -S "$socket" ]] && command -v socat >/dev/null 2>&1; then
    printf 'dispatch %s %s' "$dispatcher" "$arg" | socat -t 1 - "UNIX-CONNECT:$socket" >/dev/null 2>&1
    return 0
  fi

  return 1
}

cursor_json="$(hypr_json cursorpos || true)"
clients_json="$(hypr_json clients || true)"

if [[ -z "$cursor_json" || -z "$clients_json" ]]; then
  log "failed to query Hyprland state"
  notify "Hyprland" "Could not read cursor/window state"
  exit 1
fi

read -r cursor_x cursor_y < <(
  jq -r '[.x, .y] | @tsv' <<<"$cursor_json"
)

target="$(
  jq -r --argjson x "$cursor_x" --argjson y "$cursor_y" '
    [
      .[]
      | select(.mapped == true)
      | select(.hidden == false)
      | select(($x >= .at[0]) and ($x < (.at[0] + .size[0])))
      | select(($y >= .at[1]) and ($y < (.at[1] + .size[1])))
    ]
    | sort_by(.focusHistoryID // 999999)
    | .[0]
    | if . then [.address, .class, .title] | @tsv else empty end
  ' <<<"$clients_json"
)"

if [[ -z "$target" ]]; then
  log "no target at cursor ${cursor_x},${cursor_y}"
  notify "Hyprland" "No window under cursor"
  exit 0
fi

IFS=$'\t' read -r address class title <<<"$target"
log "closing address=$address class=$class title=$title cursor=${cursor_x},${cursor_y}"

if ! hypr_dispatch closewindow "address:$address"; then
  log "closewindow failed for address=$address class=$class"
  notify "Hyprland" "Could not close hovered window"
  exit 1
fi
