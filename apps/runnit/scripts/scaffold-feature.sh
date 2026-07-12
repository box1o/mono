#!/usr/bin/env bash
set -euo pipefail

name="${1:-}"
[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || {
	printf 'usage: %s <kebab-case-feature-name>\n' "${0##*/}" >&2
	exit 2
}

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
feature="$root/src/features/$name"
[[ ! -e "$feature" ]] || {
	printf 'feature already exists: %s\n' "$feature" >&2
	exit 1
}

mkdir -p "$feature"
component="$(printf '%s' "$name" | awk -F- '{ for (i = 1; i <= NF; i++) printf "%s", toupper(substr($i, 1, 1)) substr($i, 2) }')"

sed "s/__FEATURE__/$component/g" "$root/scripts/templates/feature.tsx" >"$feature/$name.tsx"
sed "s/__FEATURE__/$component/g; s/__FILE__/$name/g" "$root/scripts/templates/feature-index.ts" >"$feature/index.ts"

printf 'created %s\n' "$feature"
