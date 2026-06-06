#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland, Quickshell, and Hyprpaper..."

hyprctl reload

pkill hyprpaper 2>/dev/null || true

sleep 0.5

hyprpaper &>/dev/null &
qs --reload &>/dev/null

notify-send "Reload Complete" \
  "Hyprland, Quickshell, and Hyprpaper reloaded."
