#!/usr/bin/env bash
set -euo pipefail

echo "Reloading Hyprland, Hyprpaper, and Quickshell..."

# Reload Hyprland configuration
hyprctl reload

# Reapply wallpapers from hyprpaper.conf
grep -A1 '^wallpaper {' ~/.config/hypr/hyprpaper.conf | awk '
  /monitor/ {
    m=$3
    gsub(/^["\x27]|["\x27]$/, "", m)
  }
  /path/ {
    p=$3
    gsub(/^["\x27]|["\x27]$/, "", p)
    print m, p
    m=""
    p=""
  }
' | while read -r monitor path; do
  [ -f "$path" ] || continue
  hyprctl hyprpaper preload "$path" 2>/dev/null || true
  hyprctl hyprpaper wallpaper "$monitor,$path" 2>/dev/null || true
done

# Restart Quickshell
pkill -x qs 2>/dev/null || true

# Wait for old process to exit
for _ in {1..50}; do
  pgrep -x qs >/dev/null || break
  sleep 0.1
done

# Start Quickshell again
nohup qs >/dev/null 2>&1 &

# Wait for Quickshell to initialize
for _ in {1..50}; do
  pgrep -x qs >/dev/null && break
  sleep 0.1
done

# Wait for notification service to register on D-Bus (up to 10s)
for _ in {1..20}; do
  if dbus-send --session \
    --dest=org.freedesktop.Notifications \
    --type=method_call \
    --print-reply \
    /org/freedesktop/Notifications \
    org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

# Send notification
notify-send \
  "Reload Complete" \
  "Hyprland, Hyprpaper, and Quickshell have been reloaded."

echo "Done."
