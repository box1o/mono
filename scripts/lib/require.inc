[[ -n "${MONO_REQUIRE_INC:-}" ]] && return 0
MONO_REQUIRE_INC=1

has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

need_cmd() {
	has_cmd "$1" || die "missing command: $1"
}

need_any_cmd() {
	local cmd

	for cmd in "$@"; do
		if has_cmd "$cmd"; then
			printf '%s\n' "$cmd"
			return 0
		fi
	done

	die "missing one of: $*"
}

need_file() {
	[[ -f "$1" ]] || die "missing file: $1"
}

need_dir() {
	[[ -d "$1" ]] || die "missing directory: $1"
}
