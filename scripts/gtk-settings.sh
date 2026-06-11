#!/usr/bin/env bash

set -euo pipefail

schema="org.gnome.desktop.interface"
config="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"

if [[ ! -f "$config" ]]; then
  exit 0
fi

if ! command -v gsettings >/dev/null 2>&1; then
  exit 0
fi

read_ini_value() {
  local key="$1"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$config" | head -n 1
}

apply_gsetting() {
  local gkey="$1"
  local ini_key="$2"
  local value

  value="$(read_ini_value "$ini_key")"
  [[ -n "$value" ]] || return 0

  gsettings set "$schema" "$gkey" "$value" >/dev/null 2>&1 || true
}

apply_gsetting gtk-theme gtk-theme-name
apply_gsetting icon-theme gtk-icon-theme-name
apply_gsetting font-name gtk-font-name
apply_gsetting cursor-theme gtk-cursor-theme-name
apply_gsetting cursor-size gtk-cursor-theme-size

if [[ "$(read_ini_value gtk-application-prefer-dark-theme)" == "true" ]]; then
  gsettings set "$schema" color-scheme "prefer-dark" >/dev/null 2>&1 || true
fi
