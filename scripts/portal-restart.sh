#!/usr/bin/env bash

set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@" >/dev/null 2>&1 || true
  fi
}

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment \
    DISPLAY \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    >/dev/null 2>&1 || true

  systemctl --user daemon-reload >/dev/null 2>&1 || true

  # Do not start graphical-session.target directly.
  systemctl --user start hyprland-session.target >/dev/null 2>&1 || true

  systemctl --user reset-failed \
    xdg-desktop-portal.service \
    xdg-desktop-portal-hyprland.service \
    xdg-desktop-portal-gtk.service \
    >/dev/null 2>&1 || true

  systemctl --user stop xdg-desktop-portal.service >/dev/null 2>&1 || true
  systemctl --user stop xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
  systemctl --user stop xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true

  sleep 1

  systemctl --user start xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
  systemctl --user start xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
  systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true

  echo
  echo "== Session =="
  systemctl --user status hyprland-session.target --no-pager || true
  systemctl --user status graphical-session.target --no-pager || true

  echo
  echo "== Portals =="
  systemctl --user status xdg-desktop-portal.service --no-pager || true
  systemctl --user status xdg-desktop-portal-hyprland.service --no-pager || true
  systemctl --user status xdg-desktop-portal-gtk.service --no-pager || true

  echo
  echo "== D-Bus portal name =="
  busctl --user status org.freedesktop.portal.Desktop || true
else
  pkill -x xdg-desktop-portal 2>/dev/null || true
  pkill -x xdg-desktop-portal-hyprland 2>/dev/null || true
  pkill -x xdg-desktop-portal-gtk 2>/dev/null || true
fi

notify "Portal restarted" "Hyprland portal services were restarted."
