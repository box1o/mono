[[ -n "${MONO_DESKTOP_INC:-}" ]] && return 0
MONO_DESKTOP_INC=1

wayland_env_vars() {
	printf '%s\n' \
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
		_JAVA_AWT_WM_NONREPARENTING
}

export_wayland_env() {
	export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
	export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
	export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
	export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
	export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"
	export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
	export CLUTTER_BACKEND="${CLUTTER_BACKEND:-wayland}"
	export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
	export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
	export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"
	export _JAVA_AWT_WM_NONREPARENTING="${_JAVA_AWT_WM_NONREPARENTING:-1}"
}

import_wayland_env() {
	local vars

	mapfile -t vars < <(wayland_env_vars)

	if has_cmd dbus-update-activation-environment; then
		dbus-update-activation-environment --systemd "${vars[@]}" >/dev/null 2>&1 || true
	fi

	if has_cmd systemctl; then
		systemctl --user import-environment "${vars[@]}" >/dev/null 2>&1 || true
	fi
}

restart_user_units() {
	local unit

	has_cmd systemctl || return 0

	systemctl --user reset-failed "$@" >/dev/null 2>&1 || true
	systemctl --user stop "$@" >/dev/null 2>&1 || true
	sleep "${PORTAL_RESTART_DELAY:-1}"

	for unit in "$@"; do
		systemctl --user start "$unit" >/dev/null 2>&1 || true
	done
}
