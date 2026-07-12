#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config theme

REPO_DIR="$(repo_root)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_FILE="${THEME_STATE:-$(mono_config_home)/theme}"
DEFAULT_PRESET="${THEME_DEFAULT:-modern}"
PRESETS="${THEME_PRESETS:-common modern}"

themes_root() {
	if [[ -d "$CONFIG_HOME/themes/common" ]]; then
		printf '%s/themes\n' "$CONFIG_HOME"
		return 0
	fi

	printf '%s/configs/themes\n' "$REPO_DIR"
}

valid_preset() {
	local preset="$1"

	[[ " $PRESETS " == *" $preset "* ]]
}

current_preset() {
	local saved=""

	if [[ -f "$STATE_FILE" ]]; then
		saved="$(tr -d '[:space:]' <"$STATE_FILE")"
	fi

	if valid_preset "$saved"; then
		printf '%s\n' "$saved"
	else
		printf '%s\n' "$DEFAULT_PRESET"
	fi
}

copy_preset_file() {
	local src_dir="$1"
	local rel="$2"

	copy_file "$src_dir/$rel" "$CONFIG_HOME/$rel"
}

apply_preset() {
	local preset="$1"
	local root src_dir

	valid_preset "$preset" || die "unknown theme preset: $preset"

	root="$(themes_root)"
	src_dir="$root/$preset"

	need_dir "$src_dir"

	copy_preset_file "$src_dir" gtk-3.0/settings.ini
	copy_preset_file "$src_dir" gtk-4.0/settings.ini
	copy_preset_file "$src_dir" qt5ct/qt5ct.conf
	copy_preset_file "$src_dir" qt6ct/qt6ct.conf
	copy_preset_file "$src_dir" kdeglobals

	mkdir_parent "$STATE_FILE"
	printf '%s\n' "$preset" >"$STATE_FILE"

	"$MONO_SCRIPT_DIR/gtk-settings.sh"
	notify "Theme" "$preset"
}

toggle_preset() {
	if [[ "$(current_preset)" == common ]]; then
		apply_preset modern
	else
		apply_preset common
	fi
}

usage() {
	printf 'Usage: %s {apply|toggle|current|list|common|modern}\n' "$0" >&2
}

case "${1:-apply}" in
apply)
	apply_preset "${2:-$(current_preset)}"
	;;
toggle)
	toggle_preset
	;;
current)
	current_preset
	;;
list)
	printf '%s\n' $PRESETS
	;;
common | modern)
	apply_preset "$1"
	;;
*)
	usage
	exit 1
	;;
esac
