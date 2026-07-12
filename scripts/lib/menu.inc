[[ -n "${MONO_MENU_INC:-}" ]] && return 0
MONO_MENU_INC=1

menu_pick() {
	local prompt="$1"

	if has_cmd rofi; then
		if [[ -n "${ROFI_THEME:-}" ]]; then
			rofi -dmenu -i -p "$prompt" -theme "$ROFI_THEME"
		else
			rofi -dmenu -i -p "$prompt"
		fi
		return 0
	fi

	if has_cmd fzf; then
		fzf --prompt "$prompt> "
		return 0
	fi

	cat
}

confirm() {
	local prompt="$1"
	local answer

	[[ "${YES:-false}" == true ]] && return 0

	while true; do
		read -r -p "$prompt [y/n]: " answer || return 1

		case "$answer" in
		y | Y)
			return 0
			;;
		n | N)
			return 1
			;;
		esac
	done
}

copy_text() {
	local cmd

	cmd="$(need_any_cmd wl-copy xclip xsel pbcopy)"

	case "$cmd" in
	wl-copy)
		wl-copy
		;;
	xclip)
		xclip -selection clipboard
		;;
	xsel)
		xsel --clipboard --input
		;;
	pbcopy)
		pbcopy
		;;
	esac
}
