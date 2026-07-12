[[ -n "${MONO_PROCESS_INC:-}" ]] && return 0
MONO_PROCESS_INC=1

run() {
	if [[ "${DRY_RUN:-false}" == true ]]; then
		printf 'dry-run:' >&2
		printf ' %q' "$@" >&2
		printf '\n' >&2
		return 0
	fi

	"$@"
}

run_bg_once() {
	local process="$1"
	shift

	pgrep -xu "$USER" "$process" >/dev/null 2>&1 && return 0
	has_cmd "$1" || return 0

	"$@" >/dev/null 2>&1 &
}

kill_pids() {
	local pids="${1:-}"

	[[ -n "$pids" ]] || return 0
	kill $pids 2>/dev/null || true
}
