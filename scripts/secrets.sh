#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config secrets

REPO_DIR="$(repo_root)"
SECRETS_DIR="${SECRETS_DIR:-$REPO_DIR/secrets}"
CONFIGS_DIR="${CONFIGS_DIR:-$REPO_DIR/configs}"
INCLUDE_FILE="${SECRETS_INCLUDE:-$SECRETS_DIR/include.list}"
EXCLUDE_FILE="${SECRETS_EXCLUDE:-$SECRETS_DIR/exclude.list}"
ARCHIVE="${SECRETS_ARCHIVE:-$CONFIGS_DIR/secret.tar.gz.age}"
PLAIN_ARCHIVE="$CONFIGS_DIR/secret.tar.gz"

CLEANUP=()

cleanup() {
	local path

	for path in "${CLEANUP[@]:-}"; do
		rm -rf "$path"
	done

	rm -f "$PLAIN_ARCHIVE"
}

trap cleanup EXIT

usage() {
	printf 'Usage: %s {pack|restore|list|verify|pass}\n' "$0"
}

require_manifest() {
	need_file "$INCLUDE_FILE"
	need_file "$EXCLUDE_FILE"
}

require_archive() {
	need_file "$ARCHIVE"
}

generate_passphrase() {
	if has_cmd openssl; then
		openssl rand -base64 48
	else
		LC_ALL=C tr -dc 'A-Za-z0-9_-+=' </dev/urandom | head -c 64
		printf '\n'
	fi
}

valid_include_path() {
	local rel="$1"

	[[ -n "$rel" ]] || return 1
	[[ "$rel" != /* ]] || return 1
	[[ "$rel" != *..* ]] || return 1
}

append_existing_include() {
	local rel="$1"
	local list_file="$2"

	rel="${rel#./}"

	if ! valid_include_path "$rel"; then
		warn "skipped unsafe path: $rel"
		return 0
	fi

	if [[ -e "$HOME/$rel" ]]; then
		printf '%s\n' "$rel" >>"$list_file"
	else
		warn "missing: $HOME/$rel"
	fi
}

build_file_lists() {
	local list_file="$1"
	local exclude_file="$2"
	local line

	: >"$list_file"
	: >"$exclude_file"

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
		append_existing_include "$line" "$list_file"
	done <"$INCLUDE_FILE"

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
		printf '%s\n' "$line" >>"$exclude_file"
	done <"$EXCLUDE_FILE"

	[[ -s "$list_file" ]] || die "no include paths found"
}

new_workdir() {
	local work

	work="$(plain_tmpdir secrets)"
	CLEANUP+=("$work")
	printf '%s\n' "$work"
}

pack_archive() {
	local work encrypted_tmp

	need_cmd age
	require_manifest

	mkdir -p "$SECRETS_DIR" "$CONFIGS_DIR"

	work="$(new_workdir)"
	build_file_lists "$work/include.list" "$work/exclude.list"

	(
		cd "$HOME"
		tar --exclude-from "$work/exclude.list" --files-from "$work/include.list" -czf "$PLAIN_ARCHIVE"
	)

	encrypted_tmp="$ARCHIVE.tmp.$$"
	age -p -o "$encrypted_tmp" "$PLAIN_ARCHIVE"
	mv "$encrypted_tmp" "$ARCHIVE"
	rm -f "$PLAIN_ARCHIVE"

	ok "written: $ARCHIVE"
}

decrypt_archive() {
	local out="$1"

	need_cmd age
	require_archive

	age -d -o "$out" "$ARCHIVE"
}

list_archive() {
	local work tar_file

	work="$(new_workdir)"
	tar_file="$work/secrets.tar.gz"

	decrypt_archive "$tar_file"
	tar -tzf "$tar_file"
}

restore_entry() {
	local src="$1"
	local rel="$2"
	local dst="$HOME/$rel"
	local action

	if [[ -e "$dst" || -L "$dst" ]]; then
		action="$(printf 'skip\noverwrite\nbackup\n' | menu_pick "exists: ~/$rel")"

		case "$action" in
		backup)
			mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
			;;
		overwrite)
			rm -rf "$dst"
			;;
		*)
			return 0
			;;
		esac
	fi

	mkdir -p "$(dirname "$dst")"
	cp -a "$src" "$dst"
}

fix_secret_permissions() {
	[[ -d "$HOME/.ssh" ]] || return 0

	chmod 700 "$HOME/.ssh"
	find "$HOME/.ssh" -type f -exec chmod 600 {} +
	find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +
}

restore_archive() {
	local work tar_file staging entry rel

	work="$(new_workdir)"
	tar_file="$work/secrets.tar.gz"
	staging="$work/staging"

	decrypt_archive "$tar_file"
	mkdir -p "$staging"
	tar -xzf "$tar_file" -C "$staging"

	while IFS= read -r -d '' entry; do
		rel="${entry#$staging/}"
		restore_entry "$entry" "$rel"
	done < <(find "$staging" -mindepth 1 -print0 | sort -z)

	fix_secret_permissions
	ok "restore complete"
}

verify_archive_safety() {
	local tracked

	need_cmd age
	require_manifest

	tracked="$(git -C "$REPO_DIR" ls-files \
		'secrets/plain/**' \
		'secrets/staging/**' \
		'secrets/home-secrets.tar.gz' \
		'configs/secret.tar.gz' \
		'*.decrypted' 2>/dev/null || true)"

	[[ -z "$tracked" ]] || die "plaintext secret artifacts are tracked: $tracked"
	ok "secrets verified"
}

case "${1:-}" in
pack)
	pack_archive
	;;
restore)
	restore_archive
	;;
list)
	list_archive
	;;
verify)
	verify_archive_safety
	;;
pass | password | passphrase)
	generate_passphrase
	;;
-h | --help | help | '')
	usage
	;;
*)
	die "unknown command: $1"
	;;
esac
