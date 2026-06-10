#!/bin/bash
# Decode clipboard image entries to /tmp/ for display in the clipboard popup.
# This runs before cliphist list so images are ready when the list loads.

cliphist list | head -n 50 | while read -r line; do
  if echo "$line" | grep -q 'binary data'; then
    id=$(echo "$line" | cut -f1)
    if [ ! -f "/tmp/clip_$id.png" ]; then
      echo "$line" | cliphist decode > "/tmp/clip_$id.png" 2>/dev/null
    fi
  fi
done
