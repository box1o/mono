#!/usr/bin/env bash

set -euo pipefail

print_error() {
  cat << "EOF"
    ./brightnesscontrol.sh <action>
    ...valid actions are...
        i -- <i>ncrease brightness [+5%]
        d -- <d>ecrease brightness [-5%]
EOF
}

send_notification() {
  local brightness
  local brightinfo
  local bar

  brightness="$(brightnessctl info | grep -oP "(?<=\\()\\d+(?=%)")"
  brightinfo="$(brightnessctl info | awk -F "'" '/Device/ {print $2}')"
  bar="$(seq -s "." "$((brightness / 15))" | sed 's/[0-9]//g')"
  notify-send -a "brightness" -r 91190 -t 900 -i display-brightness-symbolic "${brightness}${bar}" "${brightinfo}"
}

get_brightness() {
  brightnessctl -m | grep -o '[0-9]\+%' | head -c-2
}

case "${1:-}" in
i)  # increase the backlight
  if [[ "$(get_brightness)" -lt 10 ]]; then
    brightnessctl set +1%
  else
    brightnessctl set +5%
  fi
  send_notification ;;
d)  # decrease the backlight
  if [[ "$(get_brightness)" -le 1 ]]; then
    brightnessctl set 1%
  elif [[ "$(get_brightness)" -le 10 ]]; then
    brightnessctl set 1%-
  else
    brightnessctl set 5%-
  fi
  send_notification ;;
*)  # print error
  print_error
  exit 1 ;;
esac
