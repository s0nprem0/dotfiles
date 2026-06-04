#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland config, Quickshell bar, SwayNC, and Hyprpaper..."

hyprctl reload

pkill quickshell 2>/dev/null || true
pkill swaync 2>/dev/null || true
pkill hyprpaper 2>/dev/null || true

sleep 0.5

# Re-apply WiFi window rule (windowrules.lua rules don't survive hyprctl reload)
hyprctl eval 'hl.window_rule({ name = "qwifi", match = { class = "org.quickshell" }, float = true, pin = true, move = { "monitor_w-window_w-12", "40" }, size = { 380, 460 }, no_initial_focus = true })'

# Start quickshell bar
qs -p ~/.config/quickshell/bar.qml &>/dev/null &
disown

swaync &>/dev/null &
hyprpaper &>/dev/null &

notify-send "Reload Complete" \
  "Hyprland, Quickshell bar, SwayNC, and Hyprpaper reloaded."
