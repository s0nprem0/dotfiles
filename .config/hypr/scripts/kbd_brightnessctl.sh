#!/usr/bin/env bash
DEVICE=$(brightnessctl -l | grep 'kbd_backlight' | awk -F"'|'" '{print $2}')
STEP=1
ICON="~/.config/hypr/icons/keyboard.png"

case $1 in
up) brightnessctl -d $DEVICE set ${STEP}+ ;;
down) brightnessctl -d $DEVICE set ${STEP}- ;;
esac

CURRENT=$(brightnessctl -d $DEVICE get)
MAX=$(brightnessctl -d $DEVICE max)
PERCENT=$((CURRENT * 100 / MAX))

swaync-client -t "Keyboard Backlight" -m "Level: $CURRENT/$MAX" \
  -i $ICON \
  --progress $PERCENT \
  --timeout 1000
