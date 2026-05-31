#!/bin/bash

echo "Reloading Hyprland config, Waybar, SwayNC, and Hyprpaper..."

pkill waybar 2>/dev/null
pkill swaync 2>/dev/null
pkill hyprpaper 2>/dev/null

sleep 0.5

waybar &>/dev/null &
swaync &>/dev/null &
hyprpaper &>/dev/null &

hyprctl reload

notify-send "Reload Complete" \
  "Hyprland, Waybar, SwayNC, and Hyprpaper reloaded."
