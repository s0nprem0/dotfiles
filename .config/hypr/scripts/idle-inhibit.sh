#!/usr/bin/env bash
set -euo pipefail

# Inhibits system idle when any window is fullscreen (video/game/etc.)

PID_FILE="/tmp/hypr-fullscreen-inhibit.pid"

cleanup() {
    [[ -f "$PID_FILE" ]] || return
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup EXIT INT TERM

start_inhibit() {
    [[ -f "$PID_FILE" ]] && return
    systemd-inhibit --what=idle:sleep --who=hypr-fullscreen --why="Fullscreen window active" sleep infinity &
    echo $! > "$PID_FILE"
}

stop_inhibit() {
    [[ -f "$PID_FILE" ]] || return
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
}

while true; do
    if hyprctl -j clients 2>/dev/null | jq -e 'map(select(.fullscreen == true)) | length > 0' >/dev/null 2>&1; then
        start_inhibit
    else
        stop_inhibit
    fi
    sleep 2
done
