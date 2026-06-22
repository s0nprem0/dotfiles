#!/bin/bash

if ! command -v playerctl &>/dev/null; then
  echo "No playerctl"
  exit 1
fi

status=$(playerctl status 2>/dev/null)

if [[ $status == "Playing" || $status == "Paused" ]]; then
  artist=$(playerctl metadata artist 2>/dev/null)
  title=$(playerctl metadata title 2>/dev/null)
  if [[ -n "$artist" && -n "$title" ]]; then
    echo "$artist - $title"
  elif [[ -n "$title" ]]; then
    echo "$title"
  else
    echo "Unknown"
  fi
else
  echo "No music playing"
fi
