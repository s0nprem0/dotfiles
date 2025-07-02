#!/usr/bin/env bash

# Directory for brightness icons (ensure these exist and are accessible)
# Adjust this path if your icons are in a different location.
iDIR="$HOME/.config/dunst/icons/brightness" # Common path for Dunst icons

# Get the actual backlight device
# This should match what 'brightnessctl -l' shows for your backlight.
DEVICE=$(brightnessctl -l | grep -m 1 'backlight' | awk -F"'|'" '{print $2}')

# Check if a device was found
if [ -z "$DEVICE" ]; then
  notify-send "Brightness Error" "No backlight device found by brightnessctl." -t 3000 -u critical
  exit 1
fi

# Get current brightness percentage
get_current_brightness() {
  local current_raw=$(brightnessctl -d "$DEVICE" get)
  local max_raw=$(brightnessctl -d "$DEVICE" max)
  echo $((current_raw * 100 / max_raw))
}

# Get icon based on current brightness level
get_icon() {
  local current_percent=$(get_current_brightness)
  if [ "$current_percent" -le "20" ]; then
    echo "$iDIR/brightness-20.png"
  elif [ "$current_percent" -le "40" ]; then
    echo "$iDIR/brightness-40.png"
  elif [ "$current_percent" -le "60" ]; then
    echo "$iDIR/brightness-60.png"
  elif [ "$current_percent" -le "80" ]; then
    echo "$iDIR/brightness-80.png"
  else
    echo "$iDIR/brightness-100.png"
  fi
}

# Send Dunst notification using notify-send
notify_user() {
  local current_percent=$(get_current_brightness)
  local icon_path=$(get_icon)

  # -h string:x-canonical-private-synchronous:brightness_notif : This is the replacement ID for Dunst.
  # It ensures the notification updates instead of creating new ones.
  # -h int:value:$current_percent : This passes the value for the progress bar.
  # -u low : Sets the urgency to low (less intrusive).
  # -t 1000 : Sets the timeout to 1 second (1000 milliseconds).
  notify-send \
    -h string:x-canonical-private-synchronous:brightness_notif \
    -h int:value:"$current_percent" \
    -u low \
    -t 1000 \
    -i "$icon_path" \
    "Brightness" "Adjusted to $current_percent%"
}

# Change brightness
change_brightness() {
  brightnessctl -d "$DEVICE" set "$1" -n
  notify_user # Call notify after changing brightness
}

# Execute accordingly
case "$1" in
"up")
  change_brightness "+10%"
  ;;
"down")
  change_brightness "10%-"
  ;;
"--get") # If you need to just get the brightness and notify (e.g., on startup)
  notify_user
  ;;
*)
  echo "Usage: $0 [up|down|--get]"
  exit 1
  ;;
esac
