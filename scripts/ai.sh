#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config ai

TARGET="."
IGNORE="${AI_IGNORE:-node_modules,build,dist,.next,.cache,__pycache__,vendor,target,coverage,.vscode,package-lock.json,yarn.lock,pnpm-lock.yaml}"
PROMPT="${AI_PROMPT:-Please analyze this project structure.}"

usage() {
	printf 'Usage: %s [directory] [--ignore csv] [--ignore-only csv] [--prompt text]\n' "$0"
}

parse_args() {
	while (($# > 0)); do
		case "$1" in
		--ignore)
			IGNORE="$IGNORE,${2:-}"
			shift
			;;
		--ignore-only)
			IGNORE="${2:-}"
			shift
			;;
		--prompt)
			PROMPT="${2:-}"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			TARGET="$1"
			;;
		esac

		shift
	done
}

build_tree_ignore_args() {
	local item

	ignore_args=(-I .git)
	IFS=',' read -ra items <<<"$IGNORE"

	for item in "${items[@]}"; do
		[[ -n "$item" ]] && ignore_args+=(-I "$item")
	done
}

is_text_file() {
	file "$1" | grep -q text
}

write_header() {
	printf 'AI PROJECT ANALYSIS PROMPT\n'
	printf '%s\n\n' "$PROMPT"
}

write_tree() {
	printf 'PROJECT STRUCTURE\n'
	tree --gitignore -a "${ignore_args[@]}" "$TARGET"
	printf '\n'
}

write_file_contents() {
	local path

	printf 'FILE CONTENTS\n'

	while IFS= read -r -d '' path; do
		if ! is_text_file "$path"; then
			printf '\n--- FILE: %s (binary skipped) ---\n' "$path"
			continue
		fi

		printf '\n--- FILE: %s ---\n' "$path"
		sed '' "$path"
	done < <(find "$TARGET" -type f -not -path '*/.git/*' -print0)
}

write_output() {
	{
		write_header
		write_tree
		write_file_contents
	} >"$out"
}

emit_output() {
	if has_cmd wl-copy; then
		wl-copy <"$out"
		ok "copied project context to clipboard"
	else
		sed '' "$out"
	fi
}

parse_args "$@"

need_cmd tree
need_cmd file
need_dir "$TARGET"

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

build_tree_ignore_args
write_output
emit_output
