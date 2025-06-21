#!/usr/bin/env bash
DEVICE=$(brightnessctl -l | grep -m 1 'backlight' | awk -F"'" '{print $2}')

case $1 in
up) brightnessctl -d $DEVICE set 5%+ -e4 -n2 ;;
down) brightnessctl -d $DEVICE set 5%- -e4 -n2 ;;
*) exit 1 ;;
esac

CURRENT=$(brightnessctl -d $DEVICE get)
MAX=$(brightnessctl -d $DEVICE max)
PERCENT=$((CURRENT * 100 / MAX))

swaync-client -t "Brightness" \
  -m " " \
  --progress $PERCENT \
  --timeout 800 \
  --replace-id 101 \
  --icon display-brightness-symbolic \
  --app-name "System"
