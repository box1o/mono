

#!/bin/bash

# Check if Waybar is running
if pgrep -x "waybar" > /dev/null; then
    notify-send "Waybar" "Restarting Waybar..." -t 500
    killall waybar && waybar &
else
    notify-send "Waybar" "Starting Waybar..." -t 500
    waybar &
fi
