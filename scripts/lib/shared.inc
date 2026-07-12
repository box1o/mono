[[ -n "${MONO_SHARED_INC:-}" ]] && return 0
MONO_SHARED_INC=1

MONO_SCRIPT_PATH="${BASH_SOURCE[1]:-${0}}"
MONO_SCRIPT_DIR="$(cd -- "$(dirname -- "$MONO_SCRIPT_PATH")" && pwd)"
MONO_SCRIPT_NAME="$(basename -- "$MONO_SCRIPT_PATH")"
MONO_SCRIPT_ID="${MONO_SCRIPT_NAME%.*}"
MONO_LIB_DIR="${MONO_LIB_DIR:-$MONO_SCRIPT_DIR/lib}"

source "$MONO_LIB_DIR/log.inc"
source "$MONO_LIB_DIR/config.inc"
source "$MONO_LIB_DIR/require.inc"
source "$MONO_LIB_DIR/fs.inc"
source "$MONO_LIB_DIR/process.inc"
source "$MONO_LIB_DIR/menu.inc"
