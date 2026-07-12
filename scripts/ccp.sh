#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config ccp

CONFIG_FILE=""
VERBOSE=false
COPY=false

usage() {
	printf 'Usage: %s -f <paths-file> [-v] [-c]\n' "$0"
}

parse_args() {
	while (($# > 0)); do
		case "$1" in
		-f | --file)
			CONFIG_FILE="${2:-}"
			shift
			;;
		-v | --verbose)
			VERBOSE=true
			;;
		-c | --copy)
			COPY=true
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			die "unknown option: $1"
			;;
		esac

		shift
	done
}

normalize_path() {
	local path="$1"

	path="${path%\"}"
	path="${path#\"}"
	path="${path%\'}"
	path="${path#\'}"
	path="${path/#\~/$HOME}"

	printf '%s\n' "$path"
}

append_file() {
	local file="$1"
	local out="$2"

	if [[ ! -f "$file" ]]; then
		warn "missing: $file"
		return 0
	fi

	$VERBOSE && log "reading $file"

	{
		printf '====\n%s\n====\n' "$file"
		sed '' "$file"
		printf '\n\n'
	} >>"$out"
}

build_output() {
	local out="$1"
	local line file

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

		file="$(normalize_path "$line")"
		append_file "$file" "$out"
	done <"$CONFIG_FILE"
}

main() {
	local out

	parse_args "$@"
	need_file "$CONFIG_FILE"

	out="$(mktemp)"
	trap 'rm -f "$out"' EXIT

	build_output "$out"
	sed '' "$out"

	if $COPY; then
		copy_text <"$out"
	fi
}

main "$@"
