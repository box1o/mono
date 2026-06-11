#!/usr/bin/env bash

set -euo pipefail

run_once() {
  local process="$1"
  shift

  pgrep -xu "$USER" "$process" >/dev/null 2>&1 && return 0
  command -v "$1" >/dev/null 2>&1 || return 0

  "$@" >/dev/null 2>&1 &
}

# -------------------------------------------------------------------
# Core Hyprland / Wayland / portal environment
# -------------------------------------------------------------------

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

# Hyprland normally sets WAYLAND_DISPLAY. Do not invent it unless missing.
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# GTK / Qt / Electron / Java Wayland friendliness.
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export CLUTTER_BACKEND="${CLUTTER_BACKEND:-wayland}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
export _JAVA_AWT_WM_NONREPARENTING="${_JAVA_AWT_WM_NONREPARENTING:-1}"

# -------------------------------------------------------------------
# Import environment into D-Bus and the systemd user manager
# -------------------------------------------------------------------

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    GDK_BACKEND \
    QT_QPA_PLATFORM \
    CLUTTER_BACKEND \
    SDL_VIDEODRIVER \
    MOZ_ENABLE_WAYLAND \
    ELECTRON_OZONE_PLATFORM_HINT \
    _JAVA_AWT_WM_NONREPARENTING \
    >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment \
    DISPLAY \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    GDK_BACKEND \
    QT_QPA_PLATFORM \
    CLUTTER_BACKEND \
    SDL_VIDEODRIVER \
    MOZ_ENABLE_WAYLAND \
    ELECTRON_OZONE_PLATFORM_HINT \
    _JAVA_AWT_WM_NONREPARENTING \
    >/dev/null 2>&1 || true

  systemctl --user daemon-reload >/dev/null 2>&1 || true

  # Do not start graphical-session.target directly; systemd refuses that.
  # Start our own Hyprland target, which binds to graphical-session.target.
  systemctl --user start hyprland-session.target >/dev/null 2>&1 || true
fi

# -------------------------------------------------------------------
# Portals
# -------------------------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
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
fi

# -------------------------------------------------------------------
# Polkit agent
# -------------------------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user start hyprpolkitagent.service >/dev/null 2>&1 || true
fi

if ! pgrep -xu "$USER" hyprpolkitagent >/dev/null 2>&1 && command -v hyprpolkitagent >/dev/null 2>&1; then
  hyprpolkitagent >/dev/null 2>&1 &
elif ! pgrep -xu "$USER" polkit-gnome-authentication-agent-1 >/dev/null 2>&1 && [[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &
fi

# -------------------------------------------------------------------
# Keyring
# -------------------------------------------------------------------

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
  eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>/dev/null || true)"
  export SSH_AUTH_SOCK
fi

# -------------------------------------------------------------------
# Desktop services
# -------------------------------------------------------------------

run_once udiskie udiskie --tray --automount
run_once hypridle hypridle

if command -v hyprsunset >/dev/null 2>&1 && ! pgrep -xu "$USER" hyprsunset >/dev/null 2>&1; then
  (hyprsunset -t 5000 >/dev/null 2>&1 || hyprsunset >/dev/null 2>&1) &
fi

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  xdg-user-dirs-update >/dev/null 2>&1 || true
fi

exit 0
