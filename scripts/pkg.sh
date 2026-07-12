#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config pkg
need_cmd fzf

CMD=""
AUR=false

ensure_arch() {
	if [[ ! -r /etc/os-release ]]; then
		return 0
	fi

	source /etc/os-release

	if [[ "${ID_LIKE:-$ID}" != *arch* && "${ID:-}" != arch ]]; then
		die "pkg supports Arch-based systems only"
	fi
}

usage() {
	printf 'Usage: %s {install|list|remove} [--aur]\n' "$0"
}

parse_args() {
	while (($# > 0)); do
		case "$1" in
		-a | --aur)
			AUR=true
			;;
		-h | --help | help)
			usage
			exit 0
			;;
		*)
			if [[ -n "$CMD" ]]; then
				die "unknown argument: $1"
			fi

			CMD="$1"
			;;
		esac

		shift
	done

	[[ -n "$CMD" ]] || die "missing command"
}

fzf_args() {
	local prompt="$1"
	local preview="$2"

	printf '%s\n' \
		--multi \
		--prompt "$prompt " \
		--delimiter '::' \
		--preview "$preview" \
		--preview-window 'down:55%:wrap' \
		--preview-label ' tab: multi-select, /: search, enter: confirm '
}

select_pacman_packages() {
	local prompt="$1"
	local opts

	mapfile -t opts < <(fzf_args "$prompt" 'pacman -Si $(echo {} | cut -d " " -f 1)')

	pacman -Ss "" |
		awk '
			/^[a-z]+\/[^[:space:]]+/ {
				split($1, repo, "/")
				pkg = repo[2]
				getline desc
				sub(/^[ \t]+/, "", desc)
				printf "%s :: %s\n", pkg, desc
			}
		' |
		fzf "${opts[@]}" |
		cut -d ' ' -f 1
}

select_installed_packages() {
	local prompt="$1"
	local opts

	mapfile -t opts < <(fzf_args "$prompt" 'pacman -Qi $(echo {} | cut -d " " -f 1)')

	pacman -Qei |
		awk '
			BEGIN { name = ""; desc = "" }
			/^Name[[:space:]]*:/ { name = $3 }
			/^Description[[:space:]]*:/ { desc = substr($0, index($0, $3)) }
			/^$/ && name && desc {
				printf "%s :: %s\n", name, desc
				name = ""
				desc = ""
			}
		' |
		fzf "${opts[@]}" |
		cut -d ' ' -f 1
}

select_aur_packages() {
	local prompt="$1"
	local query opts

	need_cmd yay

	read -r -p 'AUR query: ' query
	[[ ${#query} -ge 3 ]] || die "query too short"

	mapfile -t opts < <(fzf_args "$prompt" 'yay -Si $(echo {} | cut -d " " -f 1)')

	yay -Ssa "$query" |
		awk '
			/^[^ ]/ {
				split($1, repo, "/")
				pkg = repo[2]
				next
			}
			/^[ ]/ {
				desc = $0
				sub(/^[ \t]+/, "", desc)
				printf "%s :: %s\n", pkg, desc
			}
		' |
		fzf "${opts[@]}" |
		cut -d ' ' -f 1
}

select_installed_aur_packages() {
	local prompt="$1"
	local opts

	need_cmd yay

	mapfile -t opts < <(fzf_args "$prompt" 'yay -Qi $(echo {} | cut -d " " -f 1)')

	yay -Qm |
		awk '{ print $1 " :: AUR package" }' |
		fzf "${opts[@]}" |
		cut -d ' ' -f 1
}

install_packages() {
	local packages

	if $AUR; then
		packages="$(select_aur_packages 'Filter AUR packages to install...')"
		[[ -n "$packages" ]] && yay -S --answerclean N --needed $packages
	else
		packages="$(select_pacman_packages 'Search packages to install...')"
		[[ -n "$packages" ]] && sudo pacman -Syu --needed $packages
	fi
}

list_packages() {
	if $AUR; then
		select_installed_aur_packages 'Search installed AUR packages...' >/dev/null
	else
		select_installed_packages 'Search installed packages...' >/dev/null
	fi
}

remove_packages() {
	local packages

	if $AUR; then
		packages="$(select_installed_aur_packages 'Search installed AUR packages to remove...')"
	else
		packages="$(select_installed_packages 'Search installed packages to remove...')"
	fi

	[[ -n "$packages" ]] && sudo pacman -Rns $packages
}

main() {
	parse_args "$@"
	ensure_arch

	case "$CMD" in
	install)
		install_packages
		;;
	list)
		list_packages
		;;
	remove)
		remove_packages
		;;
	*)
		die "unknown command: $CMD"
		;;
	esac
}

main "$@"
