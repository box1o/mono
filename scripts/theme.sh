#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_FILE="${MONO_THEME_STATE:-$CONFIG_HOME/mono/theme}"
DEFAULT_PRESET="modern"

PRESETS=(common modern)

themes_root() {
  if [[ -d "$CONFIG_HOME/themes/common" ]]; then
    printf '%s/themes\n' "$CONFIG_HOME"
    return 0
  fi
  if [[ -d "$REPO_DIR/configs/themes/common" ]]; then
    printf '%s/configs/themes\n' "$REPO_DIR"
    return 0
  fi
  return 1
}

preset_dir() {
  local preset="$1"
  local root
  root="$(themes_root)" || {
    echo "theme.sh: theme presets not found" >&2
    exit 1
  }
  printf '%s/%s\n' "$root" "$preset"
}

valid_preset() {
  local preset="$1"
  local name
  for name in "${PRESETS[@]}"; do
    [[ "$name" == "$preset" ]] && return 0
  done
  return 1
}

current_preset() {
  if [[ -f "$STATE_FILE" ]]; then
    local saved
    saved="$(tr -d '[:space:]' <"$STATE_FILE")"
    if valid_preset "$saved"; then
      printf '%s\n' "$saved"
      return 0
    fi
  fi
  printf '%s\n' "$DEFAULT_PRESET"
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@" >/dev/null 2>&1 || true
  fi
}

usage() {
  cat <<EOF
Usage:
  theme.sh [command] [preset]

Commands:
  apply [common|modern]   Apply a theme preset (default: saved or $DEFAULT_PRESET)
  toggle                  Switch between common and modern
  current                 Print the active preset
  list                    List available presets

Presets:
  common   Plasma Breeze GTK (breeze-gtk) + Qt Breeze Dark
  modern   Adwaita GTK (adw-gtk3-dark) + Qt Breeze Dark
EOF
}

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p -- "$(dirname -- "$dst")"
  cp -f -- "$src" "$dst"
}

apply_preset() {
  local preset="$1"
  local src_dir

  valid_preset "$preset" || {
    echo "theme.sh: unknown preset: $preset" >&2
    exit 1
  }

  src_dir="$(preset_dir "$preset")"
  [[ -d "$src_dir" ]] || {
    echo "theme.sh: preset directory not found: $src_dir" >&2
    exit 1
  }

  copy_file "$src_dir/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-3.0/settings.ini"
  copy_file "$src_dir/gtk-4.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini"
  copy_file "$src_dir/qt5ct/qt5ct.conf" "$CONFIG_HOME/qt5ct/qt5ct.conf"
  copy_file "$src_dir/qt6ct/qt6ct.conf" "$CONFIG_HOME/qt6ct/qt6ct.conf"
  copy_file "$src_dir/kdeglobals" "$CONFIG_HOME/kdeglobals"

  mkdir -p -- "$(dirname -- "$STATE_FILE")"
  printf '%s\n' "$preset" >"$STATE_FILE"

  if [[ -x "$SCRIPT_DIR/gtk-settings.sh" ]]; then
    "$SCRIPT_DIR/gtk-settings.sh"
  fi

  case "$preset" in
    common)
      notify "Theme" "Common: Plasma Breeze GTK + Qt Breeze Dark"
      ;;
    modern)
      notify "Theme" "Modern: Adwaita GTK + Qt Breeze Dark"
      ;;
  esac
}

toggle_preset() {
  local active next
  active="$(current_preset)"
  if [[ "$active" == "common" ]]; then
    next="modern"
  else
    next="common"
  fi
  apply_preset "$next"
  printf '%s\n' "$next"
}

main() {
  local command="${1:-apply}"
  local preset="${2:-}"

  case "$command" in
    apply)
      apply_preset "${preset:-$(current_preset)}"
      ;;
    toggle)
      toggle_preset >/dev/null
      ;;
    current)
      current_preset
      ;;
    list)
      printf '%s\n' "${PRESETS[@]}"
      ;;
    -h|--help|help)
      usage
      ;;
    common|modern)
      apply_preset "$command"
      ;;
    *)
      echo "theme.sh: unknown command: $command" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
