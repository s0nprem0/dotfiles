#!/bin/bash
set -euo pipefail

# Decode clipboard image entries to cache dir for display in the clipboard popup.

cache_dir="/tmp/quickshell"
mkdir -p "$cache_dir"

cliphist list 2>/dev/null | head -n 50 | while read -r line; do
  if echo "$line" | grep -q 'binary data'; then
    id=$(echo "$line" | cut -f1)
    target="$cache_dir/clip_${id}.png"
    if [ ! -f "$target" ]; then
      echo "$line" | cliphist decode >"$target" 2>/dev/null || true
    fi
  fi
done
