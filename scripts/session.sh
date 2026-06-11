#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-menu}"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

pick_action() {
  local options
  options="lock
suspend
logout
reboot
shutdown"

  if command -v rofi >/dev/null 2>&1; then
    printf '%s\n' "$options" | rofi -dmenu -i -p session
  else
    printf '%s\n' "$options" | fzf
  fi
}

confirm_action() {
  local action="$1"
  local answer

  case "$action" in
    reboot|shutdown|logout)
      if command -v rofi >/dev/null 2>&1; then
        [[ "$(printf 'no\nyes\n' | rofi -dmenu -i -p "$action?")" == "yes" ]]
      else
        printf '%s [y/N]: ' "$action" >&2
        read -r answer
        [[ "$answer" == y || "$answer" == Y ]]
      fi
      ;;
    *) return 0 ;;
  esac
}

run_action() {
  local action="$1"

  case "$action" in
    lock)
      if command -v hyprlock >/dev/null 2>&1; then
        hyprlock
      else
        loginctl lock-session
      fi
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
    shutdown|poweroff)
      systemctl poweroff
      ;;
    hibernate)
      loginctl lock-session || true
      systemctl hibernate
      ;;
    menu)
      action="$(pick_action)"
      [[ -n "$action" ]] || exit 0
      confirm_action "$action" || exit 0
      run_action "$action"
      ;;
    *)
      notify "Session action failed" "Unknown action: $action"
      printf 'Usage: %s {menu|lock|suspend|logout|reboot|shutdown|hibernate}\n' "$0" >&2
      exit 1
      ;;
  esac
}

run_action "$ACTION"
