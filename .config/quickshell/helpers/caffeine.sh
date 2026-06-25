#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/quickshell_caffeine"

case "${1:-}" in
  toggle)
    if [[ -f "$STATE_FILE" ]]; then
      rm -f "$STATE_FILE"
      systemctl --user stop hypridle-inhibit 2>/dev/null || true
      pkill -f "systemd-inhibit.*quickshell-caffeine" 2>/dev/null || true
      echo '{"active":false}'
    else
      touch "$STATE_FILE"
      systemd-inhibit --what="sleep:idle:handle-lid-switch" \
        --who="quickshell-caffeine" \
        --why="Manual caffeine toggle" \
        sleep infinity &
      echo '{"active":true}'
    fi
    ;;
  status)
    if [[ -f "$STATE_FILE" ]]; then
      echo '{"active":true}'
    else
      echo '{"active":false}'
    fi
    ;;
  on)
    touch "$STATE_FILE"
    systemd-inhibit --what="sleep:idle:handle-lid-switch" \
      --who="quickshell-caffeine" \
      --why="Manual caffeine toggle" \
      sleep infinity &
    echo '{"active":true}'
    ;;
  off)
    rm -f "$STATE_FILE"
    systemctl --user stop hypridle-inhibit 2>/dev/null || true
    pkill -f "systemd-inhibit.*quickshell-caffeine" 2>/dev/null || true
    echo '{"active":false}'
    ;;
  *)
    echo '{"error":"Usage: caffeine.sh <toggle|status|on|off>"}' >&2
    exit 1
    ;;
esac
