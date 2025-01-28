#!/usr/bin/env bash
set -euo pipefail

# Returns 0 → no media playing (safe to idle/sleep)
# Returns 1 → media actively playing (skip idle action)

if ! command -v playerctl &>/dev/null; then
    exit 0
fi

if [[ -z "$(playerctl -l 2>/dev/null)" ]]; then
    exit 0
fi

if playerctl status 2>/dev/null | grep -q "Playing"; then
    exit 1
fi

exit 0
