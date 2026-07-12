[[ -n "${MONO_WAYBAR_INC:-}" ]] && return 0
MONO_WAYBAR_INC=1

json_escape() {
	python3 -c 'import json, sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

waybar_json() {
	local text tooltip class

	text="$(printf '%s' "${1:-}" | json_escape)"
	tooltip="$(printf '%s' "${2:-}" | json_escape)"
	class="$(printf '%s' "${3:-}" | json_escape)"

	printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
}
