#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland config, Quickshell, SwayNC, and Hyprpaper..."

hyprctl reload

pkill -x quickshell 2>/dev/null || true
pkill -x qs 2>/dev/null || true
pkill -x swaync 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true

sleep 0.5

hyprpaper &
swaync &
qs --no-duplicate &

sleep 1

# If Quickshell creates a normal window:
hyprctl dispatch focuswindow "class:^(quickshell)$" 2>/dev/null || true

notify-send "Reload Complete" \
  "Hyprland, Quickshell, SwayNC, and Hyprpaper reloaded."
