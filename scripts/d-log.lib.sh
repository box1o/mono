#!/usr/bin/env bash

fatal() {
	printf 'FATAL: %s\n' "$*" >&2
	exit 1
}

log() {
	printf '%s\n' "$*"
}

err() {
	printf 'ERROR: %s\n' "$*" >&2
}

wrn() {
	printf 'WARN: %s\n' "$*" >&2
}

gbl_fatal() {
	fatal "$@"
}

gbl_log() {
	log "$@"
}

gbl_err() {
	err "$@"
}

error_trap() {
	trap 'fatal "error on line ${LINENO}"' ERR
}
