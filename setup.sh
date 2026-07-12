#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MONO_LIB_DIR="$REPO_DIR/scripts/lib"

source "$MONO_LIB_DIR/log.inc"
source "$MONO_LIB_DIR/config.inc"
source "$MONO_LIB_DIR/require.inc"
source "$MONO_LIB_DIR/fs.inc"
source "$MONO_LIB_DIR/process.inc"
source "$MONO_LIB_DIR/menu.inc"

CONFIG_SRC="$REPO_DIR/configs"
SCRIPT_SRC="$REPO_DIR/scripts"
ICONS_SRC="$REPO_DIR/icons"
RUNNIT_SRC="$REPO_DIR/apps/runnit"
PKG_LIST="$REPO_DIR/pkg.list"
LOG_FILE="$REPO_DIR/install.log"
CONFIG_IGNORE_FILE="$CONFIG_SRC/.deployignore"

CONFIG_DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DEST="$HOME/.local/share/bin"
YAY_DIR="$HOME/yay"

BACKUP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/mono/backups"
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"

INSTALL_PACKAGES=false
DEPLOY_CONFIGS=false
DEPLOY_SCRIPTS=false
DEPLOY_APPS=false
RUN_POSTINSTALL=false
REPLACE=false
YES=false
DRY_RUN=false

usage() {
	cat <<EOF_USAGE
Usage: ./setup.sh [options]

Options:
  --all              Install packages, configs, scripts, apps, and post-install tasks.
  --packages         Install packages from pkg.list.
  --configs          Deploy configs into \$HOME and \$XDG_CONFIG_HOME.
  --scripts          Deploy scripts into ~/.local/share/bin.
  --apps             Build and install local applications.
  --postinstall      Run optional post-install tasks.
  --replace          Back up and replace existing files.
  -y, --yes          Accept prompts.
  --dry-run          Print actions without changing files.
  -h, --help         Show this help.
EOF_USAGE
}

parse_args() {
	if (($# == 0)); then
		usage
		exit 0
	fi

	while (($# > 0)); do
		case "$1" in
		--all)
			INSTALL_PACKAGES=true
			DEPLOY_CONFIGS=true
			DEPLOY_SCRIPTS=true
			DEPLOY_APPS=true
			RUN_POSTINSTALL=true
			;;
		--packages)
			INSTALL_PACKAGES=true
			;;
		--configs)
			DEPLOY_CONFIGS=true
			;;
		--scripts)
			DEPLOY_SCRIPTS=true
			;;
		--apps)
			DEPLOY_APPS=true
			;;
		--postinstall)
			RUN_POSTINSTALL=true
			;;
		--replace)
			REPLACE=true
			;;
		-y | --yes)
			YES=true
			;;
		--dry-run)
			DRY_RUN=true
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

ensure_arch() {
	grep -qiE 'arch|cachyos|endeavouros|manjaro' /etc/os-release || die "Arch-based system required"
}

ensure_yay() {
	if has_cmd yay; then
		ok "yay installed"
		return 0
	fi

	ensure_arch
	run sudo pacman -S --needed --noconfirm git base-devel

	if [[ ! -d "$YAY_DIR" ]]; then
		run git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
	fi

	(
		cd "$YAY_DIR"
		run makepkg -si --noconfirm
	)
}

packages_from_list() {
	awk 'NF && $1 !~ /^#/ { print $1 }' "$PKG_LIST"
}

install_packages() {
	local packages

	need_file "$PKG_LIST"
	ensure_arch
	ensure_yay

	: >"$LOG_FILE"
	mapfile -t packages < <(packages_from_list)

	if ((${#packages[@]} == 0)); then
		warn "no packages found"
		return 0
	fi

	if $DRY_RUN; then
		printf 'dry-run: yay -S --needed %s\n' "${packages[*]}"
		return 0
	fi

	yay -S --needed "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
}

config_relpath() {
	local path="$1"

	[[ "$path" == "$CONFIG_SRC"/* ]] || return 1
	printf '%s\n' "${path#$CONFIG_SRC/}"
}

trim() {
	local value="$1"

	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s\n' "$value"
}

config_ignored() {
	local path="$1"
	local rel pattern

	[[ -f "$CONFIG_IGNORE_FILE" ]] || return 1
	rel="$(config_relpath "$path")" || return 1

	while IFS= read -r pattern || [[ -n "$pattern" ]]; do
		pattern="${pattern%%#*}"
		pattern="$(trim "$pattern")"
		[[ -z "$pattern" || "$pattern" == .deployignore ]] && continue

		pattern="${pattern#./}"
		[[ "$pattern" == */ ]] && pattern="${pattern%/}"

		if [[ "$rel" == "$pattern" || "$rel" == "$pattern"/* || "$rel" == $pattern ]]; then
			return 0
		fi
	done <"$CONFIG_IGNORE_FILE"

	return 1
}

install_file() {
	local src="$1"
	local dst="$2"

	if [[ -e "$dst" && "$REPLACE" != true ]]; then
		warn "exists, skipped: $dst"
		return 0
	fi

	if $DRY_RUN; then
		return 0
	fi

	if [[ -e "$dst" && "$REPLACE" == true ]]; then
		backup_file "$dst"
	fi

	mkdir -p "$(dirname "$dst")"
	cp -f "$src" "$dst"

	if [[ -x "$src" ]]; then
		chmod +x "$dst"
	fi
}

install_config_file() {
	local src="$1"
	local dst="$2"

	if config_ignored "$src"; then
		warn "ignored: $(config_relpath "$src")"
		return 0
	fi

	install_file "$src" "$dst"
}

copy_tree() {
	local src_dir="$1"
	local dst_dir="$2"
	local file rel

	if [[ "$DRY_RUN" != true ]]; then
		mkdir -p "$dst_dir"
	fi

	while IFS= read -r -d '' file; do
		rel="${file#$src_dir/}"

		if [[ "$file" == "$CONFIG_SRC"/* ]]; then
			install_config_file "$file" "$dst_dir/$rel"
		else
			install_file "$file" "$dst_dir/$rel"
		fi
	done < <(find "$src_dir" -type f -print0)
}

patch_template_paths() {
	local file
	local files=(
		"$CONFIG_DEST/qt5ct/qt5ct.conf"
		"$CONFIG_DEST/qt6ct/qt6ct.conf"
		"$CONFIG_DEST/gtk-3.0/settings.ini"
		"$CONFIG_DEST/gtk-4.0/settings.ini"
	)

	for file in "${files[@]}"; do
		if $DRY_RUN; then
			continue
		fi

		[[ -f "$file" ]] || continue
		sed -i "s|@HOME@|$HOME|g; s|@CONFIG_DIR@|$CONFIG_DEST|g" "$file"
	done
}

deploy_icons() {
	local dir
	local name
	local dst

	[[ -d "$ICONS_SRC" ]] || return 0

	log "deploying icons"

	while IFS= read -r -d '' dir; do
		name="$(basename "$dir")"
		dst="$HOME/.local/share/icons/$name"

		if [[ -d "$dst" ]]; then
			warn "icon theme exists, skipped: $name"
			continue
		fi

		copy_tree "$dir" "$dst"
	done < <(find "$ICONS_SRC" -mindepth 1 -maxdepth 1 -type d -print0)
}

deploy_shell_configs() {
	log "deploy shell configs"

	install_config_file "$CONFIG_SRC/.bashrc" "$HOME/.bashrc"
	install_config_file "$CONFIG_SRC/.zshrc" "$HOME/.zshrc"
	install_config_file "$CONFIG_SRC/.shellrc" "$HOME/.shellrc"
	install_config_file "$CONFIG_SRC/.gitconfig" "$HOME/.gitconfig"
	install_config_file "$CONFIG_SRC/.tmux.conf" "$HOME/.config/tmux/tmux.conf"

	if [[ -f "$CONFIG_SRC/kdeglobals" ]]; then
		install_config_file "$CONFIG_SRC/kdeglobals" "$HOME/.config/kdeglobals"
	fi
}

deploy_config_dirs() {
	local dir name

	log "deploy config directories"

	while IFS= read -r -d '' dir; do
		name="$(basename "$dir")"

		if config_ignored "$dir"; then
			warn "ignored: $name/"
			continue
		fi

		copy_tree "$dir" "$CONFIG_DEST/$name"
	done < <(find "$CONFIG_SRC" -mindepth 1 -maxdepth 1 -type d -print0)
}

deploy_standalone_config_files() {
	log "deploy standalone config files"

	if [[ -f "$CONFIG_SRC/qt-colorscheme.colors" ]]; then
		install_config_file "$CONFIG_SRC/qt-colorscheme.colors" "$CONFIG_DEST/qt-colorscheme.colors"
	fi

	if [[ -f "$CONFIG_SRC/gtk-custom.css" ]]; then
		install_config_file "$CONFIG_SRC/gtk-custom.css" "$CONFIG_DEST/gtk-custom.css"
	fi
}

reload_user_systemd() {
	has_cmd systemctl || return 0

	log "reload systemd user units"
	run systemctl --user daemon-reload || true
}

apply_default_theme() {
	[[ "$DRY_RUN" == true ]] && return 0
	[[ -x "$SCRIPT_SRC/theme.sh" ]] || return 0

	"$SCRIPT_SRC/theme.sh" apply modern || true
}

deploy_configs() {
	need_dir "$CONFIG_SRC"

	deploy_shell_configs
	deploy_config_dirs
	deploy_standalone_config_files
	patch_template_paths
	reload_user_systemd
	deploy_icons
	apply_default_theme

	ok "configs deployed"
}

deploy_scripts() {
	need_dir "$SCRIPT_SRC"

	if [[ "$DRY_RUN" != true ]]; then
		mkdir -p "$SCRIPT_DEST"
	fi

	log "deploy script tree"
	copy_tree "$SCRIPT_SRC" "$SCRIPT_DEST"

	if [[ "$DRY_RUN" != true ]]; then
		mark_deployed_scripts_executable
	fi

	ok "scripts deployed"
}

deploy_runnit() {
	local manifest="$RUNNIT_SRC/src-tauri/Cargo.toml"
	local binary="$RUNNIT_SRC/src-tauri/target/release/runnit"
	local destination="$SCRIPT_DEST/runnit"

	need_dir "$RUNNIT_SRC"
	need_file "$RUNNIT_SRC/package-lock.json"
	need_file "$manifest"
	need_cmd npm
	need_cmd cargo
	need_cmd install

	log "build Runnit frontend"
	if $DRY_RUN; then
		printf 'dry-run: (cd %q && npm ci && npm run build)\n' "$RUNNIT_SRC"
		printf 'dry-run: cargo build --release --locked --manifest-path %q\n' "$manifest"
		printf 'dry-run: install -Dm755 %q %q\n' "$binary" "$destination"
		return 0
	fi

	(
		cd "$RUNNIT_SRC"
		npm ci
		npm run build
	)

	log "build Runnit desktop binary"
	cargo build --release --locked --manifest-path "$manifest"

	log "install Runnit to $destination"
	install -Dm755 "$binary" "$destination"
	ok "Runnit installed"
}

deploy_apps() {
	deploy_runnit
}

mark_deployed_scripts_executable() {
	local script

	log "mark scripts executable"

	while IFS= read -r -d '' script; do
		chmod +x "$script"
	done < <(find "$SCRIPT_DEST" -maxdepth 1 -type f -print0)
}

find_zen_desktop_file() {
	local desktop
	local names=(
		zen.desktop
		zen-browser.desktop
		app.zen_browser.zen.desktop
	)

	for desktop in "${names[@]}"; do
		if [[ -f "$HOME/.local/share/applications/$desktop" || -f "/usr/share/applications/$desktop" ]]; then
			printf '%s\n' "$desktop"
			return 0
		fi
	done
}

set_default_browser() {
	local desktop="$1"
	local mime
	local mimes=(
		x-scheme-handler/http
		x-scheme-handler/https
		text/html
		application/xhtml+xml
		application/x-extension-html
		application/x-extension-htm
	)

	if [[ -z "$desktop" ]]; then
		warn "Zen desktop file not found"
		return 0
	fi

	if has_cmd xdg-settings; then
		run xdg-settings set default-web-browser "$desktop"
	fi

	if has_cmd xdg-mime; then
		for mime in "${mimes[@]}"; do
			run xdg-mime default "$desktop" "$mime"
		done
	fi
}

choose_shell() {
	printf 'zsh\nbash\nkeep\n' | menu_pick shell
}

install_optional_package() {
	local package="$1"
	local label="$2"

	confirm "Install $label ($package)?" || return 0

	ensure_yay

	if $DRY_RUN; then
		printf 'dry-run: yay -S --needed %s\n' "$package"
		return 0
	fi

	yay -S --needed "$package"
}

choose_login_shell() {
	local choice shell_path=""

	choice="$(choose_shell)"

	case "$choice" in
	zsh)
		shell_path=/usr/bin/zsh
		;;
	bash)
		shell_path=/usr/bin/bash
		;;
	*)
		return 0
		;;
	esac

	run chsh -s "$shell_path" "$USER"
}

postinstall() {
	choose_login_shell

	if has_cmd systemctl && confirm "Enable Bluetooth service?"; then
		run sudo systemctl enable --now bluetooth
	fi

	if has_cmd systemctl && confirm "Enable power profiles service?"; then
		run sudo systemctl enable --now power-profiles-daemon
	fi

	if confirm "Restore encrypted personal secrets?"; then
		run "$SCRIPT_SRC/secrets.sh" restore
	fi

	install_optional_package visual-studio-code-bin "proprietary VS Code"

	if has_cmd code && confirm "Install VS Code Vim extension?"; then
		run code --install-extension vscodevim.vim
	fi

	install_optional_package android-studio "Android Studio"

	if confirm "Set Zen Browser as default?"; then
		set_default_browser "$(find_zen_desktop_file)"
	fi

	if ! has_cmd tailscale; then
		install_optional_package tailscale Tailscale
	fi

	if has_cmd systemctl && confirm "Enable Tailscale service?"; then
		run sudo systemctl enable --now tailscaled
	fi

	ok "postinstall complete"
}

main() {
	parse_args "$@"

	if $INSTALL_PACKAGES && confirm "Install packages from pkg.list?"; then
		log "installing packages"
		install_packages
	fi

	if $DEPLOY_CONFIGS && confirm "Deploy configs?"; then
		log "deploying configs"
		deploy_configs
	fi

	if $DEPLOY_SCRIPTS && confirm "Deploy scripts?"; then
		log "deploying scripts"
		deploy_scripts
	fi

	if $DEPLOY_APPS && confirm "Build and install apps?"; then
		log "deploying apps"
		deploy_apps
	fi

	if $RUN_POSTINSTALL && confirm "Run post-install?"; then
		log "running post-install"
		postinstall
	fi

	ok "setup complete"
}

main "$@"
