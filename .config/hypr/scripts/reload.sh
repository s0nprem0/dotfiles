#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland, Quickshell, SwayNC, and Hyprpaper..."

hyprctl reload

pkill -x quickshell 2>/dev/null || true
pkill -x qs 2>/dev/null || true
pkill swaync 2>/dev/null || true
pkill hyprpaper 2>/dev/null || true

sleep 0.5

hyprpaper &>/dev/null &
swaync &>/dev/null &
qs --no-duplicate &>/dev/null &

notify-send "Reload Complete" \
  "Hyprland, Quickshell, SwayNC, and Hyprpaper reloaded."
