#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config wallpaper

REPO_DIR="$(repo_root)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_WALLPAPER_DIR="$CONFIG_HOME/hypr/img"
CONFIG_ROFI_THEME="$CONFIG_HOME/rofi/wallpaper.rasi"
CONFIG_HYPRPAPER="$CONFIG_HOME/hypr/hyprpaper.conf"
REPO_WALLPAPER_DIR="$REPO_DIR/configs/hypr/img"
STATE_FILE="${WALLPAPER_STATE:-$(mono_config_home)/wallpaper}"
LEGACY_STATE_FILE="$CONFIG_HOME/hypr/current-wallpaper"
THUMB_DIR="${WALLPAPER_THUMB_DIR:-$(mono_cache_home)/wallpaper-thumbs}"

rofi_theme() {
	local candidate
	local candidates=(
		"${ROFI_WALLPAPER_THEME:-}"
		"$CONFIG_ROFI_THEME"
		"$REPO_DIR/configs/rofi/wallpaper.rasi"
	)

	for candidate in "${candidates[@]}"; do
		[[ -n "$candidate" && -f "$candidate" ]] || continue
		printf '%s\n' "$candidate"
		return 0
	done

	die "no rofi wallpaper theme found"
}

find_wallpapers() {
	local dir="$1"

	shift || true
	find "$dir" -maxdepth 1 -type f \
		\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
		"$@"
}

has_wallpapers() {
	local dir="$1"

	[[ -d "$dir" ]] || return 1
	find_wallpapers "$dir" -print -quit | grep -q .
}

sync_wallpaper_library() {
	local src="$1"
	local dst="$2"
	local file

	mkdir -p "$dst"

	[[ -d "$src" ]] || return 0

	while IFS= read -r -d '' file; do
		cp -fn -- "$file" "$dst/"
	done < <(find_wallpapers "$src" -print0)
}

wallpaper_dir() {
	if [[ -n "${WALLPAPER_DIR:-}" ]]; then
		printf '%s\n' "$WALLPAPER_DIR"
		return 0
	fi

	sync_wallpaper_library "$REPO_WALLPAPER_DIR" "$CONFIG_WALLPAPER_DIR"

	if has_wallpapers "$CONFIG_WALLPAPER_DIR"; then
		printf '%s\n' "$CONFIG_WALLPAPER_DIR"
	elif has_wallpapers "$REPO_WALLPAPER_DIR"; then
		printf '%s\n' "$REPO_WALLPAPER_DIR"
	else
		die "no wallpaper directory with images found"
	fi
}

on_hyprland() {
	[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && has_cmd hyprctl
}

stop_swaybg() {
	pkill -x swaybg 2>/dev/null || true
	pkill -x swww-daemon 2>/dev/null || true
}

ensure_hyprpaper() {
	local config="$CONFIG_HYPRPAPER"
	local attempt

	if ! has_cmd hyprpaper; then
		return 1
	fi

	if ! pgrep -x hyprpaper >/dev/null 2>&1; then
		mkdir -p "$(dirname -- "$config")"
		write_hyprpaper_config "${1:-}"
		nohup hyprpaper -c "$config" >/dev/null 2>&1 &
	fi

	for attempt in $(seq 1 30); do
		if hyprctl hyprpaper listactive >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.1
	done

	return 1
}

write_hyprpaper_config() {
	local image="${1:-}"
	local config="$CONFIG_HYPRPAPER"
	local mode="${WALLPAPER_MODE:-cover}"

	mkdir -p "$(dirname -- "$config")"

	if [[ -n "$image" ]]; then
		cat >"$config" <<EOF
ipc = on
splash = false

wallpaper {
    monitor =
    path = $image
    fit_mode = $mode
}
EOF
		return 0
	fi

	if [[ -f "$config" ]]; then
		return 0
	fi

	cat >"$config" <<EOF
ipc = on
splash = false

wallpaper {
    monitor =
    path = $CONFIG_WALLPAPER_DIR/life.jpg
    fit_mode = cover
}
EOF
}

apply_with_hyprpaper() {
	local image="$1"
	local mode="${WALLPAPER_MODE:-cover}"

	ensure_hyprpaper "$image" || return 1
	write_hyprpaper_config "$image"
	hyprctl hyprpaper wallpaper ",$image,$mode"
}

apply_with_swaybg() {
	local image="$1"

	need_cmd swaybg
	stop_swaybg
	pkill -x hyprpaper 2>/dev/null || true
	nohup swaybg -i "$image" -m "${WALLPAPER_MODE:-fill}" >/dev/null 2>&1 &
}

apply_wallpaper() {
	local image="$1"

	need_file "$image"
	stop_swaybg

	if on_hyprland && has_cmd hyprpaper; then
		apply_with_hyprpaper "$image" && return 0
	fi

	apply_with_swaybg "$image"
}

first_wallpaper() {
	local dir="$1"

	find_wallpapers "$dir" -print -quit
}

restore_wallpaper() {
	local dir image=""

	dir="$(wallpaper_dir)"

	if [[ -f "$STATE_FILE" ]]; then
		image="$(<"$STATE_FILE")"
	elif [[ -f "$LEGACY_STATE_FILE" ]]; then
		image="$(<"$LEGACY_STATE_FILE")"
	fi

	if [[ ! -f "$image" ]]; then
		image="$(first_wallpaper "$dir")"
	fi

	[[ -n "$image" ]] || die "no wallpaper found"
	save_wallpaper "$image"
	apply_wallpaper "$image"
}

load_wallpapers() {
	local dir="$1"

	find_wallpapers "$dir" -print0 | sort -z
}

wallpaper_label() {
	local image="$1"
	local base="${image##*/}"

	base="${base%.*}"
	base="${base//_/ }"
	printf '%s' "$base"
}

unique_label() {
	local image="$1"
	local label="$2"
	local key="$label"
	local suffix=2

	while [[ -n "${seen_labels[$key]:-}" && "${seen_labels[$key]}" != "$image" ]]; do
		key="${label} (${suffix})"
		suffix=$((suffix + 1))
	done

	seen_labels[$key]="$image"
	printf '%s' "$key"
}

thumbnail_for() {
	local image="$1"
	local name thumb

	mkdir -p "$THUMB_DIR"
	name="$(basename -- "$image")"
	thumb="$THUMB_DIR/$name"

	if [[ ! -f "$thumb" || "$image" -nt "$thumb" ]]; then
		if has_cmd magick; then
			magick "$image" -colorspace sRGB -thumbnail 720x450^ -gravity center -extent 720x450 -strip "$thumb" >/dev/null 2>&1 || cp -f -- "$image" "$thumb"
		elif has_cmd convert; then
			convert "$image" -thumbnail 720x450^ -gravity center -extent 720x450 "$thumb" >/dev/null 2>&1 || cp -f -- "$image" "$thumb"
		else
			cp -f -- "$image" "$thumb"
		fi
	fi

	printf '%s' "$thumb"
}

build_picker_rows() {
	local i image label thumb

	for i in "${!wallpapers[@]}"; do
		image="${wallpapers[$i]}"
		label="$(unique_label "$image" "$(wallpaper_label "$image")")"
		thumb="$(thumbnail_for "$image")"
		picker_labels[$i]="$label"
		picker_thumbs[$i]="$thumb"
	done
}

choose_wallpaper_index() {
	local i

	for i in "${!wallpapers[@]}"; do
		printf '%s\0icon\x1f%s\n' "${picker_labels[$i]}" "${picker_thumbs[$i]}"
	done |
		rofi \
			-dmenu \
			-show-icons \
			-format i \
			-p Wallpapers \
			-theme "$(rofi_theme)"
}

save_wallpaper() {
	local image="$1"

	mkdir_parent "$STATE_FILE"
	printf '%s\n' "$image" >"$STATE_FILE"
}

if [[ "${1:-}" == --restore ]]; then
	restore_wallpaper
	exit 0
fi

need_cmd rofi

dir="$(wallpaper_dir)"
has_wallpapers "$dir" || die "no wallpapers in $dir"

mapfile -d '' wallpapers < <(load_wallpapers "$dir")

declare -A seen_labels=()
declare -a picker_labels=()
declare -a picker_thumbs=()

build_picker_rows

selection="$(choose_wallpaper_index || true)"
[[ "$selection" =~ ^[0-9]+$ ]] || exit 0

if ((selection < 0 || selection >= ${#wallpapers[@]})); then
	die "invalid selection"
fi

target="${wallpapers[$selection]}"

apply_wallpaper "$target"
save_wallpaper "$target"

notify "Wallpaper" "$(basename -- "$target")" -i "$target"
