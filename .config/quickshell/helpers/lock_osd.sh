#!/bin/sh
# Reads lock key state from xset, inverts it (bind fires before toggle), shows OSD
dir=$(dirname "$0")
state=$(xset -q | sed -n 's/^.*'"$1"': *//p' | awk '{print $1}')
case "$state" in
  on)  new="off" ;;
  off) new="on"  ;;
  *)   new="$state" ;;
esac
"$dir/osdctl" show "$1: $new" info 1800
