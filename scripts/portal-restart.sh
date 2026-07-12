#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"
source "$MONO_LIB_DIR/desktop.inc"

load_config portal-restart

restart_with_systemd() {
	systemctl --user daemon-reload >/dev/null 2>&1 || true
	systemctl --user start hyprland-session.target >/dev/null 2>&1 || true

	restart_user_units \
		xdg-desktop-portal-hyprland.service \
		xdg-desktop-portal-gtk.service \
		xdg-desktop-portal.service
}

show_status() {
	systemctl --user status hyprland-session.target --no-pager || true
	systemctl --user status xdg-desktop-portal.service --no-pager || true
	busctl --user status org.freedesktop.portal.Desktop || true
}

fallback_restart() {
	pkill -x xdg-desktop-portal 2>/dev/null || true
	pkill -x xdg-desktop-portal-hyprland 2>/dev/null || true
	pkill -x xdg-desktop-portal-gtk 2>/dev/null || true
}

export_wayland_env
import_wayland_env

if has_cmd systemctl; then
	restart_with_systemd
	show_status
else
	fallback_restart
fi

notify "Portal restarted" "Hyprland portal services were restarted."
