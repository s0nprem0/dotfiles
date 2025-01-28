#!/usr/bin/bash

pkill -x waybar 2>/dev/null
while pgrep -x waybar >/dev/null; do sleep 0.1; done
waybar &>/dev/null &
