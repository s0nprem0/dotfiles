#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland config, Waybar, SwayNC, and Hyprpaper..."

hyprctl reload

pkill waybar 2>/dev/null || true
pkill swaync 2>/dev/null || true
pkill hyprpaper 2>/dev/null || true

sleep 0.5

waybar &>/dev/null &
swaync &>/dev/null &
hyprpaper &>/dev/null &

notify-send "Reload Complete" \
  "Hyprland, Waybar, SwayNC, and Hyprpaper reloaded."
