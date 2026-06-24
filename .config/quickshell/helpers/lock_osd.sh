#!/bin/sh
# ; ponytail: reads lock key state from xset, shows OSD
state=$(xset -q | sed -n 's/^.*'"$1"': *//p' | awk '{print $1}')
osdctl show "$1: $state" info 1800
