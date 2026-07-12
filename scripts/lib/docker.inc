[[ -n "${MONO_DOCKER_INC:-}" ]] && return 0
MONO_DOCKER_INC=1

default_container() {
	local prefix="${1:-}"

	[[ -n "$prefix" ]] || return 1

	docker ps --format '{{.Names}}' |
		grep -E "^${prefix}" |
		head -n 1
}

container_ip() {
	docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "$1" |
		sed -n '/./{p;q;}'
}

container_running() {
	docker ps --format '{{.Names}}' | grep -Fxq "$1"
}
