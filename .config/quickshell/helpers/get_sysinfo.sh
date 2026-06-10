#!/usr/bin/env bash

printf '%s\n' "$HOSTNAME"
uname -r

. /etc/os-release
printf '%s\n' "$PRETTY_NAME"