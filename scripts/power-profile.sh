#!/usr/bin/env bash

set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

if ! command -v powerprofilesctl >/dev/null 2>&1; then
  notify "Power profiles unavailable" "powerprofilesctl is not installed."
  exit 1
fi

current="$(powerprofilesctl get 2>/dev/null || printf balanced)"

case "$current" in
  performance) next="balanced" ;;
  balanced) next="power-saver" ;;
  power-saver) next="performance" ;;
  *) next="balanced" ;;
esac

powerprofilesctl set "$next"
notify "Power profile" "$next"
