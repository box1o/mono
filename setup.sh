#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/configs"
SCRIPT_SRC="$SCRIPT_DIR/scripts"
ICONS_SRC="$SCRIPT_DIR/icons"
PKG_LIST="$SCRIPT_DIR/pkg.list"
LOG_FILE="$SCRIPT_DIR/install.log"
CONFIG_IGNORE_FILE="$CONFIG_SRC/.deployignore"

CONFIG_DEST="$HOME/.config"
SCRIPT_DEST="$HOME/.local/share/bin"
YAY_DIR="$HOME/yay"
BACKUP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/mono/backups"
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"

BLUE="\033[0;34m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

INSTALL_PACKAGES=false
DEPLOY_CONFIGS=false
DEPLOY_SCRIPTS=false
RUN_POSTINSTALL=false
REPLACE=false
YES=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage:
  ./setup.sh [options]

Options:
  --all              Install packages, deploy configs, deploy scripts, and run post-install.
  --packages         Install packages from pkg.list using yay.
  --configs          Deploy configs and icon themes (also applies default dark theme).
  --scripts          Deploy scripts to ~/.local/share/bin.
  --postinstall      Run post-install tasks.
  --replace          Replace existing deployed files.
  -y, --yes          Do not ask confirmation for selected actions.
  --dry-run          Print what would happen without writing files or installing packages.
  -h, --help         Show this help.

Examples:
  ./setup.sh --all
  ./setup.sh --packages
  ./setup.sh --configs --scripts --replace
  ./setup.sh --postinstall

Post-install:
  The post-install step asks which login shell to use, then offers optional setup
  for VS Code, Android Studio, Tailscale, and Bluetooth.
EOF
}

info() { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
ok() { printf "${GREEN}[ok]${RESET} %s\n" "$1"; }
warn() { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
fail() { printf "${RED}[x]${RESET} %s\n" "$1" >&2; }

confirm() {
  local prompt="$1"
  $YES && return 0
  local answer
  while true; do
    if ! read -r -p "$prompt [y/n]: " answer; then
      printf "\n"
      return 1
    fi
    case "$answer" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) printf "Please answer y or n.\n" ;;
    esac
  done
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        INSTALL_PACKAGES=true
        DEPLOY_CONFIGS=true
        DEPLOY_SCRIPTS=true
        RUN_POSTINSTALL=true
        ;;
      --packages) INSTALL_PACKAGES=true ;;
      --configs) DEPLOY_CONFIGS=true ;;
      --scripts) DEPLOY_SCRIPTS=true ;;
      --postinstall) RUN_POSTINSTALL=true ;;
      --replace) REPLACE=true ;;
      -y|--yes) YES=true ;;
      --dry-run) DRY_RUN=true ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

ensure_arch() {
  if ! grep -qiE 'arch|cachyos|endeavouros|manjaro' /etc/os-release; then
    fail "This installer expects an Arch-based system."
    exit 1
  fi
}

run_cmd() {
  if $DRY_RUN; then
    printf "dry-run: %s\n" "$*"
    return 0
  fi

  "$@"
}

install_optional_package() {
  local package="$1"
  local label="$2"

  if ! confirm "Install $label ($package)?"; then
    return 0
  fi

  ensure_arch
  ensure_yay

  if $DRY_RUN; then
    printf 'dry-run: yay -S --needed %s\n' "$package"
  else
    yay -S --needed "$package" 2>&1 | tee -a "$LOG_FILE"
  fi
}

find_zen_desktop_file() {
  local desktop

  for desktop in zen.desktop zen-browser.desktop app.zen_browser.zen.desktop; do
    if [[ -f "$HOME/.local/share/applications/$desktop" || -f "/usr/share/applications/$desktop" ]]; then
      printf '%s\n' "$desktop"
      return 0
    fi
  done

  if command -v rg >/dev/null 2>&1; then
    desktop="$(rg -l 'Exec=.*zen-browser|Name=.*Zen' "$HOME/.local/share/applications" /usr/share/applications 2>/dev/null | head -n 1 || true)"
  else
    desktop="$(grep -RilE 'Exec=.*zen-browser|Name=.*Zen' "$HOME/.local/share/applications" /usr/share/applications 2>/dev/null | head -n 1 || true)"
  fi

  [[ -n "$desktop" ]] && basename "$desktop"
}

set_default_browser() {
  local desktop_file="$1"
  local mime

  if [[ -z "$desktop_file" ]]; then
    warn "Zen desktop file was not found; default browser unchanged"
    return 0
  fi

  info "Setting default browser to $desktop_file"

  if command -v xdg-settings >/dev/null 2>&1; then
    run_cmd xdg-settings set default-web-browser "$desktop_file"
  else
    warn "xdg-settings is not installed"
  fi

  if command -v xdg-mime >/dev/null 2>&1; then
    for mime in \
      x-scheme-handler/http \
      x-scheme-handler/https \
      text/html \
      application/xhtml+xml \
      application/x-extension-html \
      application/x-extension-htm; do
      run_cmd xdg-mime default "$desktop_file" "$mime"
    done
  else
    warn "xdg-mime is not installed"
  fi
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay is installed"
    return 0
  fi

  info "Installing yay"
  run_cmd sudo pacman -S --needed --noconfirm git base-devel

  if [[ ! -d "$YAY_DIR" ]]; then
    run_cmd git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
  fi

  (
    cd "$YAY_DIR"
    run_cmd makepkg -si --noconfirm
  )
}

packages_from_list() {
  awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    { print $1 }
  ' "$PKG_LIST"
}

install_packages() {
  [[ -f "$PKG_LIST" ]] || { fail "Missing package list: $PKG_LIST"; exit 1; }
  ensure_arch
  ensure_yay

  : > "$LOG_FILE"
  mapfile -t packages < <(packages_from_list)

  if [[ ${#packages[@]} -eq 0 ]]; then
    warn "No packages found in pkg.list"
    return 0
  fi

  info "Installing ${#packages[@]} packages from pkg.list"
  if $DRY_RUN; then
    printf 'dry-run: yay -S --needed %s\n' "${packages[*]}"
    return 0
  fi

  yay -S --needed "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
  ok "Package installation complete"
  info "Log saved to $LOG_FILE"
}

copy_file() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" && "$REPLACE" != true ]]; then
    warn "Exists, skipped: $dst"
    return 0
  fi

  if $DRY_RUN; then
    if [[ -e "$dst" && "$REPLACE" == true ]]; then
      printf "dry-run: backup %s -> %s/%s\n" "$dst" "$BACKUP_ROOT" "$BACKUP_STAMP"
    fi
    printf "dry-run: install %s -> %s\n" "$src" "$dst"
  else
    if [[ -e "$dst" && "$REPLACE" == true ]]; then
      backup_existing_file "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
  fi

  if [[ -x "$src" && "$DRY_RUN" != true ]]; then
    chmod +x "$dst"
  fi
}

backup_existing_file() {
  local file="$1"
  local rel
  local backup

  if [[ "$file" == "$HOME/"* ]]; then
    rel="${file#$HOME/}"
  else
    rel="${file#/}"
  fi

  backup="$BACKUP_ROOT/$BACKUP_STAMP/$rel"
  mkdir -p "$(dirname "$backup")"
  cp -a "$file" "$backup"
}

config_relpath() {
  local path="$1"

  [[ "$path" == "$CONFIG_SRC"/* ]] || return 1
  printf '%s\n' "${path#$CONFIG_SRC/}"
}

config_ignored() {
  local path="$1"
  local rel

  [[ -f "$CONFIG_IGNORE_FILE" ]] || return 1
  rel="$(config_relpath "$path")" || return 1

  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    pattern="${pattern%%#*}"
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"

    [[ -z "$pattern" ]] && continue
    [[ "$pattern" == .deployignore ]] && continue

    pattern="${pattern#./}"

    if [[ "$pattern" == */ ]]; then
      pattern="${pattern%/}"
      [[ "$rel" == "$pattern" || "$rel" == "$pattern"/* ]] && return 0
    elif [[ "$rel" == "$pattern" || "$rel" == "$pattern"/* || "$rel" == $pattern ]]; then
      return 0
    fi
  done < "$CONFIG_IGNORE_FILE"

  return 1
}

copy_config_file() {
  local src="$1"
  local dst="$2"
  local rel

  if config_ignored "$src"; then
    rel="$(config_relpath "$src")"
    warn "Ignored by configs/.deployignore: $rel"
    return 0
  fi

  copy_file "$src" "$dst"
}

copy_tree_contents() {
  local src_dir="$1"
  local dst_dir="$2"

  if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$dst_dir"
  fi
  while IFS= read -r -d '' file; do
    local rel="${file#$src_dir/}"
    if [[ "$file" == "$CONFIG_SRC"/* ]]; then
      copy_config_file "$file" "$dst_dir/$rel"
    else
      copy_file "$file" "$dst_dir/$rel"
    fi
  done < <(find "$src_dir" -type f -print0)
}

patch_qt_home_paths() {
  local file

  for file in "$CONFIG_DEST/qt5ct/qt5ct.conf" "$CONFIG_DEST/qt6ct/qt6ct.conf"; do
    if $DRY_RUN; then
      printf "dry-run: replace @HOME@ and @CONFIG_DIR@ in %s\n" "$file"
    elif [[ -f "$file" ]]; then
      sed -i "s|@HOME@|$HOME|g" "$file"
      sed -i "s|@CONFIG_DIR@|$CONFIG_DEST|g" "$file"
    fi
  done
}

patch_gtk_paths() {
  local file

  for file in "$CONFIG_DEST/gtk-3.0/settings.ini" "$CONFIG_DEST/gtk-4.0/settings.ini"; do
    if $DRY_RUN; then
      printf "dry-run: replace @CONFIG_DIR@ in %s\n" "$file"
    elif [[ -f "$file" ]]; then
      sed -i "s|@CONFIG_DIR@|$CONFIG_DEST|g" "$file"
    fi
  done
}
reload_user_systemd() {
  if command -v systemctl >/dev/null 2>&1; then
    if $DRY_RUN; then
      printf "dry-run: systemctl --user daemon-reload\n"
    else
      systemctl --user daemon-reload || warn "Failed to reload systemd user units"
    fi
  fi
}

deploy_configs() {
  [[ -d "$CONFIG_SRC" ]] || { fail "Missing config directory: $CONFIG_SRC"; exit 1; }

  info "Deploying configs to $CONFIG_DEST"
  copy_config_file "$CONFIG_SRC/.bashrc" "$HOME/.bashrc"
  copy_config_file "$CONFIG_SRC/.zshrc" "$HOME/.zshrc"
  copy_config_file "$CONFIG_SRC/.shellrc" "$HOME/.shellrc"
  copy_config_file "$CONFIG_SRC/.gitconfig" "$HOME/.gitconfig"
  copy_config_file "$CONFIG_SRC/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
  [[ -f "$CONFIG_SRC/kdeglobals" ]] && copy_config_file "$CONFIG_SRC/kdeglobals" "$HOME/.config/kdeglobals"

  while IFS= read -r -d '' dir; do
    local name
    name="$(basename "$dir")"
    if config_ignored "$dir"; then
      warn "Ignored by configs/.deployignore: $name/"
      continue
    fi
    copy_tree_contents "$dir" "$CONFIG_DEST/$name"
  done < <(find "$CONFIG_SRC" -mindepth 1 -maxdepth 1 -type d -print0)

  # Copy custom color scheme files
  [[ -f "$CONFIG_SRC/qt-colorscheme.colors" ]] && copy_config_file "$CONFIG_SRC/qt-colorscheme.colors" "$CONFIG_DEST/qt-colorscheme.colors"
  [[ -f "$CONFIG_SRC/gtk-custom.css" ]] && copy_config_file "$CONFIG_SRC/gtk-custom.css" "$CONFIG_DEST/gtk-custom.css"

  patch_qt_home_paths
  patch_gtk_paths
  reload_user_systemd

  # Deploy icon themes
  deploy_icons

  # Apply dark theme by default
  if [[ -x "$SCRIPT_SRC/theme.sh" ]] && ! $DRY_RUN; then
    info "Applying default dark theme (modern preset)"
    "$SCRIPT_SRC/theme.sh" apply modern || warn "Failed to apply theme"
  fi

  ok "Configs deployed"
}

deploy_scripts() {
  [[ -d "$SCRIPT_SRC" ]] || { fail "Missing scripts directory: $SCRIPT_SRC"; exit 1; }

  info "Deploying scripts to $SCRIPT_DEST"
  mkdir -p "$SCRIPT_DEST"

  while IFS= read -r -d '' script; do
    local name
    name="$(basename "$script")"
    copy_file "$script" "$SCRIPT_DEST/$name"
    if ! $DRY_RUN; then
      chmod +x "$SCRIPT_DEST/$name"
    fi
  done < <(find "$SCRIPT_SRC" -maxdepth 1 -type f -print0)

  ok "Scripts deployed"
}

deploy_icons() {
  local icons_dest="$HOME/.local/share/icons"

  [[ -d "$ICONS_SRC" ]] || return 0

  info "Deploying icon themes to $icons_dest"

  while IFS= read -r -d '' icon_theme; do
    local theme_name
    theme_name="$(basename "$icon_theme")"
    copy_tree_contents "$icon_theme" "$icons_dest/$theme_name"
  done < <(find "$ICONS_SRC" -mindepth 1 -maxdepth 1 -type d -print0)

  ok "Icon themes deployed"
}

choose_shell() {
  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  printf "\nCurrent shell: %s\n" "$current_shell" >&2
  printf "Select login shell:\n" >&2
  printf "  1) zsh\n" >&2
  printf "  2) bash\n" >&2
  printf "  3) keep current\n" >&2

  local choice
  while true; do
    printf "Choice [1-3]: " >&2
    read -r choice
    case "$choice" in
      1) echo "/usr/bin/zsh"; return 0 ;;
      2) echo "/usr/bin/bash"; return 0 ;;
      3|"") echo ""; return 0 ;;
      *) printf "Choose 1, 2, or 3.\n" >&2 ;;
    esac
  done
}

postinstall() {
  info "Post-install"

  local shell_path
  shell_path="$(choose_shell)"
  if [[ -n "$shell_path" ]]; then
    if [[ ! -x "$shell_path" ]]; then
      fail "Shell not found or not executable: $shell_path"
      return 1
    fi

    if $DRY_RUN; then
      printf "dry-run: chsh -s %s %s\n" "$shell_path" "$USER"
    else
      chsh -s "$shell_path" "$USER"
    fi
    ok "Login shell set to $shell_path"
  else
    ok "Login shell unchanged"
  fi

  if command -v systemctl >/dev/null 2>&1 && confirm "Enable Bluetooth service?"; then
    run_cmd sudo systemctl enable --now bluetooth
  fi

  if command -v systemctl >/dev/null 2>&1 && confirm "Enable power profiles service?"; then
    run_cmd sudo systemctl enable --now power-profiles-daemon
  fi

  if confirm "Restore encrypted personal secrets?"; then
    if $DRY_RUN; then
      printf "dry-run: %s restore\n" "$SCRIPT_SRC/secrets.sh"
    else
      "$SCRIPT_SRC/secrets.sh" restore
    fi
  fi

  install_optional_package "visual-studio-code-bin" "proprietary VS Code"
  if command -v code >/dev/null 2>&1 && confirm "Install VS Code Vim extension?"; then
    run_cmd code --install-extension vscodevim.vim
  fi

  install_optional_package "android-studio" "Android Studio"

  if confirm "Set Zen Browser as the default browser?"; then
    set_default_browser "$(find_zen_desktop_file)"
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    install_optional_package "tailscale" "Tailscale"
  fi

  if command -v systemctl >/dev/null 2>&1 && confirm "Enable and start Tailscale service?"; then
    run_cmd sudo systemctl enable --now tailscaled
    if command -v tailscale >/dev/null 2>&1 && confirm "Run Tailscale login/setup now?"; then
      run_cmd sudo tailscale up
    fi
  fi

  ok "Post-install complete"
}

main() {
  parse_args "$@"

  if $INSTALL_PACKAGES && confirm "Install packages from pkg.list?"; then
    install_packages
  fi

  if $DEPLOY_CONFIGS && confirm "Deploy configs?"; then
    deploy_configs
  fi

  if $DEPLOY_SCRIPTS && confirm "Deploy scripts?"; then
    deploy_scripts
  fi

  if $RUN_POSTINSTALL && confirm "Run post-install?"; then
    postinstall
  fi
}

main "$@"
