#!/bin/bash

SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FULL_PATH="$SCREENSHOTS_DIR/$FILENAME"

mkdir -p "$SCREENSHOTS_DIR"

SAVE=true
COPY=true

for cmd in grim wl-copy slurp jq hyprctl; do
  if ! command -v "$cmd" &>/dev/null; then
    notify-send -a "Screenshot" "Error" "$cmd not found"
    exit 1
  fi
done

notify() { notify-send -a "Screenshot" "$1" "$2"; }

capture() {
  local label="$1"
  shift
  if $SAVE && $COPY; then
    grim "$@" "$FULL_PATH" && wl-copy <"$FULL_PATH" && notify "Screenshot Captured!" "$label saved to $FULL_PATH and copied." || notify "Screenshot Failed" "$label capture failed."
  elif $SAVE; then
    grim "$@" "$FULL_PATH" && notify "Screenshot Captured!" "$label saved to $FULL_PATH." || notify "Screenshot Failed" "$label capture failed."
  elif $COPY; then
    grim "$@" - | wl-copy && notify "Screenshot Captured!" "$label copied to clipboard." || notify "Screenshot Failed" "$label capture failed."
  fi
}

while getopts ":sc" opt; do
  case $opt in
  s) COPY=false ;;
  c) SAVE=false ;;
  *) echo "Usage: $0 [-s] [-c] [region|active|full]"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

case "${1:-full}" in
region)
  REGION=$(slurp)
  if [ -z "$REGION" ]; then
    notify "Screenshot Cancelled" "No region selected."
    exit 0
  fi
  capture "Region" -g "$REGION"
  ;;
active)
  GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
  if [ -n "$GEOM" ]; then
    capture "Active window" -g "$GEOM"
  else
    notify "Screenshot Failed" "Could not get active window info."
  fi
  ;;
full)
  capture "Full screen"
  ;;
esac
