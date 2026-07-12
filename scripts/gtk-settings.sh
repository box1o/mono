#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config gtk-settings

SCHEMA="${GTK_SCHEMA:-org.gnome.desktop.interface}"
SETTINGS_FILE="${GTK_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini}"

[[ -f "$SETTINGS_FILE" ]] || exit 0
has_cmd gsettings || exit 0

ini_value() {
	local key="$1"

	sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$SETTINGS_FILE" | head -n 1
}

apply_gsetting() {
	local gkey="$1"
	local ini_key="$2"
	local value

	value="$(ini_value "$ini_key")"
	[[ -n "$value" ]] || return 0

	gsettings set "$SCHEMA" "$gkey" "$value" >/dev/null 2>&1 || true
}

apply_color_scheme() {
	if [[ "$(ini_value gtk-application-prefer-dark-theme)" == true ]]; then
		gsettings set "$SCHEMA" color-scheme prefer-dark >/dev/null 2>&1 || true
	fi
}

apply_gsetting gtk-theme gtk-theme-name
apply_gsetting icon-theme gtk-icon-theme-name
apply_gsetting font-name gtk-font-name
apply_gsetting cursor-theme gtk-cursor-theme-name
apply_gsetting cursor-size gtk-cursor-theme-size
apply_color_scheme
