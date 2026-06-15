#!/usr/bin/env bash
# Minimal logging helpers (GBashLib log.lib.sh subset)

fatal() {
	echo -e "FATAL:\t $*\n\n---try help command for more information: d help\n" >&2
	exit 1
}

log() {
	echo -e "$@"
}

err() {
	echo -e "ERROR:\t $*" >&2
}

wrn() {
	echo -e "WARN:\t $*"
}

gbl_fatal() { fatal "$@"; }
gbl_log() { log "$@"; }
gbl_err() { err "$@"; }

error_trap() {
	trap 'fatal "error on line ${LINENO}"' ERR
}
