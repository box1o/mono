#!/bin/bash

WINDOW_TITLE="Picture-in-Picture"
LOCK_FILE="/tmp/pip-tracker.lock"
PID_FILE="/tmp/pip-tracker.pid"

cleanup() {
    rm -f "$LOCK_FILE" "$PID_FILE"
    exit 0
}

trap cleanup EXIT INT TERM

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Stopping previous instance (PID: $OLD_PID)"
        kill "$OLD_PID" 2>/dev/null
        sleep 0.5
    fi
    rm -f "$PID_FILE" "$LOCK_FILE"
fi

echo $$ > "$PID_FILE"

notify-send "PiP Tracker" "Started tracking Picture-in-Picture window"

LAST_WORKSPACE=""
LAST_ADDRESS=""

get_window_address() {
    hyprctl clients -j | jq -r --arg title "$WINDOW_TITLE" '.[] | select(.title == $title) | .address'
}

move_to_workspace() {
    ADDRESS=$(get_window_address)
    
    if [ -z "$ADDRESS" ]; then
        echo "PiP window not found, waiting..."
        sleep 1
        return
    fi
    
    WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')

    if [ "$WORKSPACE" != "$LAST_WORKSPACE" ] || [ "$ADDRESS" != "$LAST_ADDRESS" ]; then
        echo "[$(date +%T)] Moving PiP to workspace $WORKSPACE"
        hyprctl dispatch movetoworkspacesilent "$WORKSPACE,address:$ADDRESS" 2>/dev/null
        LAST_WORKSPACE="$WORKSPACE"
        LAST_ADDRESS="$ADDRESS"
    fi
}

move_to_workspace

while true; do
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | while read -r line; do
        case "$line" in
            workspace*|focusedmon*)
                move_to_workspace
                ;;
        esac
    done
    
    sleep 2
done
