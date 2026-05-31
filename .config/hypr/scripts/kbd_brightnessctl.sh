#!/usr/bin/env bash

DEVICE=$(brightnessctl -l | grep kbd_backlight | awk -F"'" '{print $2}')

if [ -z "$DEVICE" ]; then
  notify-send "Keyboard Backlight" "No backlight device found."
  exit 1
fi

STEP=1

case "${1:-}" in
up)   brightnessctl -d "$DEVICE" set "${STEP}+" 2>/dev/null ;;
down) brightnessctl -d "$DEVICE" set "${STEP}-" 2>/dev/null ;;
*)    echo "Usage: $0 {up|down}"; exit 1 ;;
esac

CURRENT=$(brightnessctl -d "$DEVICE" get)
MAX=$(brightnessctl -d "$DEVICE" max)
PERCENT=$((CURRENT * 100 / MAX))

notify-send \
  -h int:value:"$PERCENT" \
  -u low \
  -t 1000 \
  "Keyboard Backlight" "Level: $CURRENT/$MAX"
