#!/usr/bin/env bash
# Toggle or query glass effect state
# Usage: glass_toggle.sh [on|off|toggle|status]

STATE_FILE="$HOME/.cache/quickshell/glass_state"

ensure_dir() {
    mkdir -p "$(dirname "$STATE_FILE")"
}

get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "true"
    fi
}

case "${1:-}" in
    on)
        ensure_dir
        echo "true" > "$STATE_FILE"
        echo "Glass effect: ON"
        ;;
    off)
        ensure_dir
        echo "false" > "$STATE_FILE"
        echo "Glass effect: OFF"
        ;;
    toggle)
        ensure_dir
        current=$(get_state)
        if [[ "$current" == "true" ]]; then
            echo "false" > "$STATE_FILE"
            echo "Glass effect: OFF"
        else
            echo "true" > "$STATE_FILE"
            echo "Glass effect: ON"
        fi
        ;;
    status|--status|-s)
        current=$(get_state)
        if [[ "$current" == "true" ]]; then
            echo "Glass effect: ON"
        else
            echo "Glass effect: OFF"
        fi
        ;;
    *)
        ensure_dir
        echo "true" > "$STATE_FILE"
        ;;
esac