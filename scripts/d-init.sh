#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

target="${1:-./d.bl.sh}"

if [[ -e "$target" ]]; then
	die "already exists: $target"
fi

cp -- "$MONO_SCRIPT_DIR/d.bl.sh.example" "$target"
chmod +x "$target"

ok "created: $target"
