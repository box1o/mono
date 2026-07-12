#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/desktop.inc"

load_config desktop-services

start_session_units() {
	has_cmd systemctl || return 0

	systemctl --user daemon-reload >/dev/null 2>&1 || true
	systemctl --user start hyprland-session.target >/dev/null 2>&1 || true

	restart_user_units \
		xdg-desktop-portal-hyprland.service \
		xdg-desktop-portal-gtk.service \
		xdg-desktop-portal.service

	systemctl --user start hyprpolkitagent.service >/dev/null 2>&1 || true
}

start_polkit_agent() {
	if pgrep -xu "$USER" hyprpolkitagent >/dev/null 2>&1; then
		return 0
	fi

	if has_cmd hyprpolkitagent; then
		hyprpolkitagent >/dev/null 2>&1 &
		return 0
	fi

	if pgrep -xu "$USER" polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
		return 0
	fi

	if [[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
		/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &
	fi
}

start_keyring() {
	has_cmd gnome-keyring-daemon || return 0

	eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>/dev/null || true)"
	export SSH_AUTH_SOCK
}

start_desktop_helpers() {
	run_bg_once udiskie udiskie --tray --automount

	idle_state="$(mono_state_home)/idle/enabled"
	if [[ ! -f "$idle_state" || "$(cat "$idle_state" 2>/dev/null || true)" == enabled ]]; then
		run_bg_once hypridle hypridle
	fi

	if ! pgrep -xu "$USER" hyprsunset >/dev/null 2>&1 && has_cmd hyprsunset; then
		(hyprsunset -t "${HYPRSUNSET_TEMP:-5000}" >/dev/null 2>&1 || hyprsunset >/dev/null 2>&1) &
	fi

	if has_cmd xdg-user-dirs-update; then
		xdg-user-dirs-update >/dev/null 2>&1 || true
	fi
}

export_wayland_env
import_wayland_env
start_session_units
start_polkit_agent
start_keyring
start_desktop_helpers
