[[ -n "${MONO_ADB_INC:-}" ]] && return 0
MONO_ADB_INC=1

ADB_BIN="${ADB_BIN:-}"

resolve_adb() {
	if [[ -n "$ADB_BIN" && -x "$ADB_BIN" ]]; then
		return 0
	fi

	ADB_BIN="$(type -pa adb 2>/dev/null | head -n 1 || true)"
	[[ -n "$ADB_BIN" ]] || die "adb not found"
}

adb_cmd() {
	resolve_adb
	command "$ADB_BIN" "$@"
}

adb_serial() {
	local host="${1,,}"

	if [[ "$host" == *:* ]]; then
		printf '%s\n' "$host"
	else
		printf '%s:5555\n' "$host"
	fi
}

adb_connect() {
	adb_cmd connect "${1,,}" >/dev/null 2>&1 || true
}

adb_with_serial() {
	local host="$1"
	local serial

	shift

	serial="$(adb_serial "$host")"
	adb_connect "$host"
	adb_cmd -s "$serial" "$@"
}

adb_shell() {
	local host="$1"
	shift

	adb_with_serial "$host" shell "$@"
}
