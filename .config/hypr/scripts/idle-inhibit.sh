#!/usr/bin/env bash
set -euo pipefail

for cmd in hyprctl jq socat systemd-inhibit; do
    command -v "$cmd" >/dev/null 2>&1 || exit 0
done

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    exit 0
fi

INHIBIT_PID=""

cleanup() {
    [[ -n "$INHIBIT_PID" ]] && kill "$INHIBIT_PID" 2>/dev/null || true
    exit 0
}

trap cleanup EXIT INT TERM

start_inhibit() {
    [[ -n "$INHIBIT_PID" ]] && kill -0 "$INHIBIT_PID" 2>/dev/null && return
    systemd-inhibit --what=idle:sleep --who=hypr-fullscreen --why="Fullscreen window active" sleep infinity &
    INHIBIT_PID=$!
}

stop_inhibit() {
    [[ -z "$INHIBIT_PID" ]] && return
    kill "$INHIBIT_PID" 2>/dev/null || true
    INHIBIT_PID=""
}

# Check initial state before listening
if hyprctl -j clients 2>/dev/null | jq -e 'map(select(.fullscreen != 0)) | length > 0' >/dev/null 2>&1; then
    start_inhibit
fi

SOCKET="$XDG_RUNTIME_DIR/hypr/$(hyprctl instances -j | jq -r '.[0].instance')/.socket2.sock"
if [[ ! -S "$SOCKET" ]]; then
    exit 0
fi

while read -r line; do
    if [[ "$line" == "fullscreen>>1" ]]; then
        start_inhibit
    elif [[ "$line" == "fullscreen>>0"* ]] || [[ "$line" == "activewindow>>"* ]]; then
        if ! hyprctl -j clients 2>/dev/null | jq -e 'map(select(.fullscreen != 0)) | length > 0' >/dev/null 2>&1; then
            stop_inhibit
        fi
    fi
done < <(socat -U - UNIX-CONNECT:"$SOCKET")
