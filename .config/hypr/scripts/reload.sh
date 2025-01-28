#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland, Quickshell, and Hyprpaper..."

hyprctl reload

pkill hyprpaper 2>/dev/null || true

sleep 0.5

hyprpaper &>/dev/null &
qs --reload &>/dev/null || true

# Wait for notification service to register on D-Bus (up to 10s)
for i in $(seq 1 20); do
  if dbus-send --session --dest=org.freedesktop.Notifications \
    --type=method_call --print-reply \
    /org/freedesktop/Notifications \
    org.freedesktop.DBus.Peer.Ping &>/dev/null; then
    break
  fi
  sleep 0.5
done

notify-send "Reload Complete" \
  "Hyprland, Quickshell, and Hyprpaper reloaded."
