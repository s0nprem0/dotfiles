#!/usr/bin/env bash
n=$(cliphist list 2>/dev/null | wc -l)
echo "{\"hasItems\":$([ "$n" -gt 0 ] && echo true || echo false),\"count\":$n}"
