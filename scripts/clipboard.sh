#!/bin/bash

# Display clipboard history using cliphist and rofi
selected=$(cliphist list | rofi -dmenu -i -p "Clipboard" -theme "$HOME/.config/rofi/theme.rasi")

# If a selection was made, decode and copy it to the clipboard
if [ -n "$selected" ]; then
    echo "$selected" | cliphist decode | wl-copy
fi
