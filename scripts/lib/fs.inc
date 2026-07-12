[[ -n "${MONO_FS_INC:-}" ]] && return 0
MONO_FS_INC=1

repo_root() {
	cd "$MONO_SCRIPT_DIR/.." && pwd
}

mkdir_parent() {
	mkdir -p -- "$(dirname -- "$1")"
}

copy_file() {
	local src="$1"
	local dst="$2"

	mkdir_parent "$dst"
	cp -f -- "$src" "$dst"
}

backup_file() {
	local file="$1"
	local root stamp rel dst

	[[ -e "$file" || -L "$file" ]] || return 0

	root="${BACKUP_ROOT:-$(mono_cache_home)/backups}"
	stamp="${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"

	if [[ "$file" == "$HOME/"* ]]; then
		rel="${file#$HOME/}"
	else
		rel="${file#/}"
	fi

	dst="$root/$stamp/$rel"
	mkdir_parent "$dst"
	cp -a -- "$file" "$dst"
}

plain_tmpdir() {
	mktemp -d "${TMPDIR:-/tmp}/mono.${1:-tmp}.XXXXXX"
}
