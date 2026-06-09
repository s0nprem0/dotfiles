#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland, Quickshell, and Hyprpaper..."

hyprctl reload

grep -A1 '^wallpaper {' ~/.config/hypr/hyprpaper.conf | awk '
  /monitor/ { m=$3 }
  /path/    { p=$3; gsub(/^["\x27]|["\x27]$/,"",p); print m, p; m=""; p="" }
' | while read -r monitor path; do
  hyprctl hyprpaper preload "$path" 2>/dev/null || true
  hyprctl hyprpaper wallpaper "$monitor,$path" 2>/dev/null || true
done
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
