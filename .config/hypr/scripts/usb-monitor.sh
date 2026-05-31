#!/bin/bash

# Kill existing instance
pkill -f "udisksctl monitor" 2>/dev/null

udisksctl monitor | while read -r line; do
  case "$line" in
    *"Added"*)
      label=$(echo "$line" | grep -oP 'drive_\w+')
      notify-send -u low "USB Connected" "${label:-Device added}"
      ;;
    *"Removed"*)
      notify-send -u low "USB Disconnected" "Device removed"
      ;;
  esac
done
