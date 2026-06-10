#!/bin/bash
set -euo pipefail

# Decode clipboard image entries to /tmp/ for display in the clipboard popup.
# Runs before cliphist list so images are ready when the list loads.

cliphist list 2>/dev/null | head -n 50 | while read -r line; do
  if echo "$line" | grep -q 'binary data'; then
    id=$(echo "$line" | cut -f1)
    target="/tmp/clip_${id}.png"
    if [ ! -f "$target" ]; then
      echo "$line" | cliphist decode >"$target" 2>/dev/null || true
    fi
  fi
done
