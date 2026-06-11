#!/usr/bin/env bash

CONFIG="$HOME/.config/wofi/config/config"
STYLE="$HOME/.config/wofi/colors.css"

if [[ ! $(pidof wofi) ]]; then
    wofi --conf "${CONFIG}" --style "${STYLE}" --show drun
else
    pkill wofi
fi
