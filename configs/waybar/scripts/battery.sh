#!/usr/bin/env bash

# //NOTE: System has two batteries, but only Battery 1 has valid data

# Get battery info specifically for Battery 1
battery_info=$(acpi -b | grep "Battery 1:")
percentage=$(echo "$battery_info" | grep -o '[0-9]\+%' | tr -d '%')
status=$(echo "$battery_info" | grep -o 'Charging\|Discharging\|Full')

# Fallback if Battery 1 info can't be extracted
if [ -z "$percentage" ] || ! [[ "$percentage" =~ ^[0-9]+$ ]]; then
    # Try reading directly from sysfs
    bat_path="/sys/class/power_supply/BAT1"
    if [ -d "$bat_path" ] && [ -f "$bat_path/capacity" ]; then
        percentage=$(cat "$bat_path/capacity")
        
        if [ -f "$bat_path/status" ]; then
            status=$(cat "$bat_path/status")
        else
            status="Unknown"
        fi
    else
        # Default values if all else fails
        percentage=0
        status="Unknown"
    fi
fi

# Icon selection based on status and percentage
if [[ "$status" == "Charging" || "$status" == "charging" ]]; then
    icon="󰂄"
    class="charging"
    status_indicator="+"
elif [[ "$status" == "Full" || "$status" == "full" || "$status" == "Not charging" ]]; then
    icon="󰁹"
    class="normal"
    status_indicator="="
else
    status_indicator="-"
    if (( percentage >= 90 )); then
        icon="󰁹"
    elif (( percentage >= 80 )); then
        icon="󰂂"
    elif (( percentage >= 60 )); then
        icon="󰂀"
    elif (( percentage >= 40 )); then
        icon="󰁾"
    elif (( percentage >= 20 )); then
        icon="󰁼"
    else
        icon="󰁺"
    fi
    
    # Class determination
    if (( percentage <= 15 )); then
        class="critical"
    elif (( percentage <= 30 )); then
        class="warning"
    else
        class="normal"
    fi
fi

# Output for waybar with status indicator
echo "{\"text\":\"$icon $status_indicator$percentage%\", \"class\":\"$class\"}"
