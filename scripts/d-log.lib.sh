#!/usr/bin/env bash
# Minimal logging helpers (GBashLib log.lib.sh subset)

fatal() {
	echo -e "FATAL:\t $*" >&2
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
