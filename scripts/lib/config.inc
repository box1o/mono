[[ -n "${MONO_CONFIG_INC:-}" ]] && return 0
MONO_CONFIG_INC=1

mono_config_home() {
	printf '%s\n' "${MONO_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/mono}"
}

mono_config_file() {
	local name="$1"

	printf '%s/%s.conf\n' "$(mono_config_home)" "$name"
}

mono_state_home() {
	printf '%s\n' "${MONO_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/mono}"
}

mono_cache_home() {
	printf '%s\n' "${MONO_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/mono}"
}

load_config() {
	local name="$1"
	local file

	shift || true

	file="$(mono_config_home)/mono.conf"
	[[ -f "$file" ]] && source "$file"

	file="$(mono_config_file "$name")"
	[[ -f "$file" ]] && source "$file"

	for file in "$@"; do
		[[ -f "$file" ]] && source "$file"
	done
}

config_path() {
	local name="$1"
	local fallback="$2"
	local file

	file="$(mono_config_file "$name")"

	if [[ -f "$file" ]]; then
		printf '%s\n' "$file"
	else
		printf '%s\n' "$fallback"
	fi
}

ensure_config_dir() {
	mkdir -p "$(mono_config_home)"
}
