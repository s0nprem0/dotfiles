#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland config, Quickshell, SwayNC, and Hyprpaper..."

hyprctl reload

pkill quickshell 2>/dev/null || true
pkill swaync 2>/dev/null || true
pkill hyprpaper 2>/dev/null || true

sleep 0.5

qs &>/dev/null &
swaync &>/dev/null &
hyprpaper &>/dev/null &

notify-send "Reload Complete" \
  "Hyprland, Quickshell, SwayNC, and Hyprpaper reloaded."
