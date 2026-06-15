#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-./d.bl.sh}"

if [[ -e "$TARGET" ]]; then
	echo "d-init: already exists: $TARGET" >&2
	exit 1
fi

cp -- "$SCRIPT_DIR/d.bl.sh.example" "$TARGET"
chmod +x "$TARGET"
echo "Created $TARGET"
