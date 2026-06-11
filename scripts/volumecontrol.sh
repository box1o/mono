#!/usr/bin/env sh

# Notification ID for volume updates
NOTIFY_ID=9993

# Maximum volume level
MAX_VOLUME=100

# Function to display usage
print_error() {
    echo "Usage: ./volumecontrol.sh <action>"
    echo "Actions:"
    echo "  i - increase volume"
    echo "  d - decrease volume"
    echo "  m - mute/unmute"
    exit 1
}

# Function to send notification
notify() {
    notify-send -p -r $NOTIFY_ID "Volume" "$1"
}

# Function to change volume
change_volume() {
    current_volume=$(pamixer --get-volume)
    new_volume=$((current_volume $1))

    if [ $new_volume -gt $MAX_VOLUME ]; then
        new_volume=$MAX_VOLUME
    elif [ $new_volume -lt 0 ]; then
        new_volume=0
    fi

    pactl set-sink-volume @DEFAULT_SINK@ $new_volume%
    notify "Volume: $new_volume%"
}

# Function to mute/unmute
toggle_mute() {
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    mute_status=$(pamixer --get-mute)
    if [ "$mute_status" = "true" ]; then
        notify "Volume: Muted"
    else
        current_volume=$(pamixer --get-volume)
        notify "Volume: Unmuted ($current_volume%)"
    fi
}

# Check if an argument is provided
if [ $# -eq 0 ]; then
    print_error
fi

# Execute action based on the argument
case "$1" in
    i)
        change_volume "+5"
        ;;
    d)
        change_volume "-5"
        ;;
    m)
        toggle_mute
        ;;
    *)
        print_error
        ;;
esac
