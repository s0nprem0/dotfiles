#!/usr/bin/bash

BATTERY_PATH="/sys/class/power_supply/BAT0"
WARN_LEVEL=30
CRIT_LEVEL=15
NOTIFIED_WARN=false
NOTIFIED_CRIT=false

while true; do
  capacity=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)
  status=$(cat "$BATTERY_PATH/status" 2>/dev/null)

  [[ -z "$capacity" ]] && sleep 30 && continue

  if [[ "$status" == "Discharging" ]]; then
    if (( capacity <= CRIT_LEVEL )) && [[ "$NOTIFIED_CRIT" != "true" ]]; then
      notify-send -u critical -i battery-caution "Battery Critical" "Battery at ${capacity}%. Plug in now."
      NOTIFIED_CRIT=true
    elif (( capacity <= WARN_LEVEL )) && [[ "$NOTIFIED_WARN" != "true" ]]; then
      notify-send -u normal -i battery-low "Battery Low" "Battery at ${capacity}%."
      NOTIFIED_WARN=true
    fi
  else
    NOTIFIED_WARN=false
    NOTIFIED_CRIT=false
  fi

  sleep 60
done
