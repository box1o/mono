[[ -n "${MONO_LOG_INC:-}" ]] && return 0
MONO_LOG_INC=1

mono_color() {
	[[ -t 2 ]] || return 1

	case "$1" in
	blue)
		printf '\033[0;34m'
		;;
	green)
		printf '\033[0;32m'
		;;
	yellow)
		printf '\033[0;33m'
		;;
	red)
		printf '\033[0;31m'
		;;
	bold)
		printf '\033[1m'
		;;
	reset)
		printf '\033[0m'
		;;
	esac
}

mono_emit() {
	local color="$1"
	local tag="$2"
	local text="$3"

	printf '%s%s%s %s\n' \
		"$(mono_color "$color" || true)" \
		"$tag" \
		"$(mono_color reset || true)" \
		"$text" >&2
}

log() {
	mono_emit blue '[*]' "$*"
}

ok() {
	mono_emit green '[ok]' "$*"
}

warn() {
	mono_emit yellow '[!]' "$*"
}

err() {
	mono_emit red '[x]' "$*"
}

die() {
	err "$*"
	exit 1
}

notify() {
	command -v notify-send >/dev/null 2>&1 || return 0
	notify-send "$@" >/dev/null 2>&1 || true
}
