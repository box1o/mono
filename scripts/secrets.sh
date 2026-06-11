#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$REPO_DIR/secrets"
CONFIGS_DIR="$REPO_DIR/configs"
INCLUDE_FILE="$SECRETS_DIR/include.list"
EXCLUDE_FILE="$SECRETS_DIR/exclude.list"
ARCHIVE="$CONFIGS_DIR/secret.tar.gz.age"
PLAIN_ARCHIVE="$CONFIGS_DIR/secret.tar.gz"
CLEANUP_PATHS=()

BLUE="\033[0;34m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info() { printf "${BLUE}[*]${RESET} %s\n" "$1"; }
ok() { printf "${GREEN}[ok]${RESET} %s\n" "$1"; }
warn() { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
fail() { printf "${RED}[x]${RESET} %s\n" "$1" >&2; }

usage() {
  cat <<EOF
Usage:
  scripts/secrets.sh pack      Create/update encrypted secrets archive.
  scripts/secrets.sh restore   Restore encrypted secrets into \$HOME.
  scripts/secrets.sh list      List encrypted archive contents.
  scripts/secrets.sh verify    Check prerequisites and plaintext safety.
  scripts/secrets.sh pass      Print a strong random passphrase.
EOF
}

require_age() {
  if ! command -v age >/dev/null 2>&1; then
    fail "age is not installed. Install packages first or run: sudo pacman -S age"
    exit 1
  fi
}

require_manifest() {
  [[ -f "$INCLUDE_FILE" ]] || { fail "Missing include list: $INCLUDE_FILE"; exit 1; }
  [[ -f "$EXCLUDE_FILE" ]] || { fail "Missing exclude list: $EXCLUDE_FILE"; exit 1; }
}

require_archive() {
  [[ -f "$ARCHIVE" ]] || { fail "Missing encrypted archive: $ARCHIVE"; exit 1; }
}

generate_passphrase() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48
  else
    LC_ALL=C tr -dc 'A-Za-z0-9_-+=' < /dev/urandom | head -c 64
    printf '\n'
  fi
}

tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/mono-secrets.XXXXXX"
}

cleanup_path() {
  local path="$1"
  [[ -n "$path" && -e "$path" ]] && rm -rf "$path"
}

register_cleanup() {
  CLEANUP_PATHS+=("$1")
}

cleanup_all() {
  local path
  for path in "${CLEANUP_PATHS[@]}"; do
    cleanup_path "$path"
  done
  rm -f "$PLAIN_ARCHIVE"
}

trap cleanup_all EXIT

valid_include_path() {
  local rel="$1"
  [[ -n "$rel" ]] || return 1
  [[ "$rel" != /* ]] || return 1
  [[ "$rel" != *".."* ]] || return 1
  return 0
}

build_file_lists() {
  local list_file="$1"
  local exclude_file="$2"
  : > "$list_file"
  : > "$exclude_file"

  while IFS= read -r rel || [[ -n "$rel" ]]; do
    [[ -z "$rel" || "$rel" =~ ^[[:space:]]*# ]] && continue
    rel="${rel#./}"
    if ! valid_include_path "$rel"; then
      warn "Skipped unsafe include path: $rel"
      continue
    fi
    if [[ -e "$HOME/$rel" ]]; then
      printf '%s\n' "$rel" >> "$list_file"
    else
      warn "Missing, skipped: $HOME/$rel"
    fi
  done < "$INCLUDE_FILE"

  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
    printf '%s\n' "$pattern" >> "$exclude_file"
  done < "$EXCLUDE_FILE"

  [[ -s "$list_file" ]] || { fail "No existing include paths found"; exit 1; }
}

pack() {
  require_age
  require_manifest
  mkdir -p "$SECRETS_DIR" "$CONFIGS_DIR"

  local work
  work="$(tmpdir)"
  register_cleanup "$work"

  local list_file="$work/include.list"
  local exclude_file="$work/exclude.list"
  build_file_lists "$list_file" "$exclude_file"

  info "Creating plaintext tarball in temporary form"
  (
    cd "$HOME"
    tar --exclude-from "$exclude_file" --files-from "$list_file" -czf "$PLAIN_ARCHIVE"
  )

  info "Encrypting archive with age passphrase"
  local encrypted_tmp="${ARCHIVE}.tmp.$$"
  rm -f "$encrypted_tmp"
  if ! age -p -o "$encrypted_tmp" "$PLAIN_ARCHIVE"; then
    rm -f "$encrypted_tmp"
    fail "Encryption failed"
    exit 1
  fi
  mv "$encrypted_tmp" "$ARCHIVE"
  rm -f "$PLAIN_ARCHIVE"

  ok "Encrypted archive written: $ARCHIVE"
}

decrypt_to_tar() {
  local out="$1"
  require_age
  require_archive
  age -d -o "$out" "$ARCHIVE"
}

list_archive() {
  local work
  work="$(tmpdir)"
  register_cleanup "$work"

  local tar_file="$work/home-secrets.tar.gz"
  decrypt_to_tar "$tar_file"
  tar -tzf "$tar_file"
}

prompt_conflict() {
  local rel="$1"
  local answer
  while true; do
    read -r -p "Exists: ~/$rel [s]kip/[o]verwrite/[b]ackup: " answer || return 1
    case "${answer:-s}" in
      s|S) echo "skip"; return 0 ;;
      o|O) echo "overwrite"; return 0 ;;
      b|B) echo "backup"; return 0 ;;
      *) printf "Choose s, o, or b.\n" ;;
    esac
  done
}

copy_entry() {
  local src="$1"
  local rel="$2"
  local dst="$HOME/$rel"

  if [[ -d "$src" && ! -L "$src" ]]; then
    mkdir -p "$dst"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    local action
    action="$(prompt_conflict "$rel")" || action="skip"
    case "$action" in
      skip)
        warn "Skipped: ~/$rel"
        return 0
        ;;
      backup)
        local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dst" "$backup"
        warn "Backed up existing file to: $backup"
        ;;
      overwrite)
        rm -rf "$dst"
        ;;
    esac
  fi

  cp -a "$src" "$dst"
}

fix_permissions() {
  if [[ -d "$HOME/.ssh" ]]; then
    find "$HOME/.ssh" -type d -exec chmod 700 {} +
    find "$HOME/.ssh" -type f -exec chmod 600 {} +
    find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +
  fi

  if [[ -d "$HOME/.config/beast-rdp" ]]; then
    chmod 700 "$HOME/.config/beast-rdp"
    [[ -f "$HOME/.config/beast-rdp/password" ]] && chmod 600 "$HOME/.config/beast-rdp/password"
  fi
}

restore() {
  local work
  work="$(tmpdir)"
  register_cleanup "$work"

  local tar_file="$work/home-secrets.tar.gz"
  local staging="$work/staging"

  decrypt_to_tar "$tar_file"
  mkdir -p "$staging"
  tar -xzf "$tar_file" -C "$staging"

  info "Restoring secrets into $HOME"
  while IFS= read -r -d '' entry; do
    local rel="${entry#$staging/}"
    [[ -n "$rel" ]] || continue
    copy_entry "$entry" "$rel"
  done < <(find "$staging" -mindepth 1 -print0 | sort -z)

  fix_permissions
  ok "Secrets restore complete"
}

verify() {
  require_age
  require_manifest

  if [[ -f "$ARCHIVE" ]]; then
    ok "Encrypted archive exists"
  else
    warn "Encrypted archive not found yet: $ARCHIVE"
  fi

  local tracked_plain
  tracked_plain="$(git -C "$REPO_DIR" ls-files 'secrets/plain/**' 'secrets/staging/**' 'secrets/home-secrets.tar.gz' 'configs/secret.tar.gz' '*.decrypted' 2>/dev/null || true)"
  if [[ -n "$tracked_plain" ]]; then
    fail "Plaintext secret artifacts are tracked:"
    printf '%s\n' "$tracked_plain" >&2
    exit 1
  fi

  ok "No tracked plaintext secret artifacts found"
}

main() {
  case "${1:-}" in
    pack) pack ;;
    restore) restore ;;
    list) list_archive ;;
    verify) verify ;;
    pass|password|passphrase) generate_passphrase ;;
    -h|--help|help|"") usage ;;
    *)
      fail "Unknown command: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
