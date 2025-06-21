#!/bin/bash

# Configuration
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FULL_PATH="$SCREENSHOTS_DIR/$FILENAME"

# Ensure the directory exists
mkdir -p "$SCREENSHOTS_DIR"

# Function to display notification
send_notification() {
  notify-send -a "Screenshot" "$1" "$2"
}

# Default behavior (both save and copy)
SAVE=true
COPY=true

# Parse options
while getopts ":sc" opt; do
  case $opt in
  s) COPY=false ;; # Only save, don't copy
  c) SAVE=false ;; # Only copy, don't save
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

case "$1" in
"region")
  # Get region coordinates from slurp
  REGION=$(slurp 2>/dev/null)

  # Check if selection was cancelled (empty) or failed
  if [ -z "$REGION" ]; then
    send_notification "Screenshot Cancelled" "No region selected."
    exit 0
  fi

  # Capture the selected region
  if $SAVE && $COPY; then
    # Both save and copy
    if grim -g "$REGION" "$FULL_PATH"; then
      wl-copy <"$FULL_PATH"
      send_notification "Screenshot Captured!" "Region saved to $FULL_PATH and copied to clipboard."
    else
      send_notification "Screenshot Failed" "Failed to capture the selected region."
    fi
  elif $SAVE; then
    # Only save
    if grim -g "$REGION" "$FULL_PATH"; then
      send_notification "Screenshot Captured!" "Region saved to $FULL_PATH."
    else
      send_notification "Screenshot Failed" "Failed to capture the selected region."
    fi
  elif $COPY; then
    # Only copy
    if grim -g "$REGION" - | wl-copy; then
      send_notification "Screenshot Captured!" "Region copied to clipboard."
    else
      send_notification "Screenshot Failed" "Failed to capture the selected region."
    fi
  fi
  ;;
"active")
  # Capture active window
  ACTIVE_WINDOW_INFO=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
  if [ -n "$ACTIVE_WINDOW_INFO" ]; then
    if $SAVE && $COPY; then
      if grim -g "$ACTIVE_WINDOW_INFO" "$FULL_PATH"; then
        wl-copy <"$FULL_PATH"
        send_notification "Screenshot Captured!" "Active window saved to $FULL_PATH and copied to clipboard."
      else
        send_notification "Screenshot Failed" "Active window capture failed."
      fi
    elif $SAVE; then
      if grim -g "$ACTIVE_WINDOW_INFO" "$FULL_PATH"; then
        send_notification "Screenshot Captured!" "Active window saved to $FULL_PATH."
      else
        send_notification "Screenshot Failed" "Active window capture failed."
      fi
    elif $COPY; then
      if grim -g "$ACTIVE_WINDOW_INFO" - | wl-copy; then
        send_notification "Screenshot Captured!" "Active window copied to clipboard."
      else
        send_notification "Screenshot Failed" "Active window capture failed."
      fi
    fi
  else
    send_notification "Screenshot Failed" "Could not get active window info."
  fi
  ;;
"full")
  if $SAVE && $COPY; then
    if grim "$FULL_PATH"; then
      wl-copy <"$FULL_PATH"
      send_notification "Screenshot Captured!" "Full screen saved to $FULL_PATH and copied to clipboard."
    else
      send_notification "Screenshot Failed" "Full screen capture failed."
    fi
  elif $SAVE; then
    if grim "$FULL_PATH"; then
      send_notification "Screenshot Captured!" "Full screen saved to $FULL_PATH."
    else
      send_notification "Screenshot Failed" "Full screen capture failed."
    fi
  elif $COPY; then
    if grim - | wl-copy; then
      send_notification "Screenshot Captured!" "Full screen copied to clipboard."
    else
      send_notification "Screenshot Failed" "Full screen capture failed."
    fi
  fi
  ;;
*)
  echo "Usage: $0 [-s (save only)] [-c (copy only)] [region|active|full]"
  send_notification "Screenshot Error" "Usage: $0 [-s] [-c] [region|active|full]"
  exit 1
  ;;
esac
