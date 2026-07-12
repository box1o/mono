[[ -n "${MONO_HYPRLAND_INC:-}" ]] && return 0
MONO_HYPRLAND_INC=1

hypr_runtime_dir() {
	printf '%s/hypr/%s\n' \
		"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
		"${HYPRLAND_INSTANCE_SIGNATURE:-}"
}

hypr_socket() {
	printf '%s/.socket.sock\n' "$(hypr_runtime_dir)"
}

hypr_event_socket() {
	printf '%s/.socket2.sock\n' "$(hypr_runtime_dir)"
}

hypr_json() {
	local command="$1"
	local socket

	if has_cmd hyprctl && hyprctl -j "$command" 2>/dev/null; then
		return 0
	fi

	socket="$(hypr_socket)"
	[[ -S "$socket" ]] || return 1
	has_cmd socat || return 1

	printf '/j/%s' "$command" | socat -t 1 - "UNIX-CONNECT:$socket"
}

hypr_dispatch() {
	local dispatcher="$1"
	local arg="${2:-}"
	local socket

	if has_cmd hyprctl && hyprctl dispatch "$dispatcher" "$arg" >/dev/null 2>&1; then
		return 0
	fi

	socket="$(hypr_socket)"
	[[ -S "$socket" ]] || return 1
	has_cmd socat || return 1

	printf 'dispatch %s %s' "$dispatcher" "$arg" |
		socat -t 1 - "UNIX-CONNECT:$socket" >/dev/null 2>&1
}
