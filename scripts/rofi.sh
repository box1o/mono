#!/usr/bin/env bash

CONFIG="$HOME/.config/rofi/config.rasi"

if ! pidof rofi >/dev/null 2>&1; then
  rofi -show drun \
    -config "$CONFIG" \
    -modi "drun" \
    -show-icons
else
  pkill rofi
fi
