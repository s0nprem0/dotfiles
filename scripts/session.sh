#!/usr/bin/env bash
# Report the current desktop session and optionally start the optional
# components (waybar, mako).
#
# These are genuinely optional: nothing here is required for a session to
# start, and a missing binary is reported and skipped, never fatal.
#
# Usage:
#   scripts/session.sh            # show session status only
#   scripts/session.sh --start    # also start waybar + mako if installed
set -uo pipefail

START=false
case "${1:-}" in
  --start) START=true ;;
  "") ;;
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# ── What session are we in? ────────────────────────────────────────────────
# Order matters: a compositor may set WAYLAND_DISPLAY as well as its own
# variable, so check the specific one first.
compositor="none"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || { have hyprctl && hyprctl version >/dev/null 2>&1; }; then
  compositor="Hyprland"
elif have swaymsg && swaymsg -t get_outputs >/dev/null 2>&1; then
  compositor="Sway"
elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    compositor="WSLg (Weston)"
  else
    compositor="Wayland (unknown)"
  fi
elif [[ -n "${DISPLAY:-}" ]]; then
  compositor="X11"
else
  compositor="none (headless / TTY)"
fi

echo "Compositor:   $compositor"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-unset}"
echo "DISPLAY:      ${DISPLAY:-unset}"
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  echo "WSL distro:   $WSL_DISTRO_NAME"
fi
echo "Terminal:     ${TERM_PROGRAM:-${TERM:-unset}}"
echo "Shell:        ${SHELL:-unset}"
echo "Kitty pid:    ${KITTY_PID:-unset}"

# ── Optional components ───────────────────────────────────────────────────
for bin in waybar mako fuzzel; do
  if have "$bin"; then
    echo "  ✓ $bin"
  else
    echo "  ✗ $bin (absent — optional)"
  fi
done

if ! $START; then
  echo ""
  echo "Run with --start to launch waybar and mako."
  exit 0
fi

echo ""
started_any=false
for bin in waybar mako-notify; do
  if ! have "$bin"; then
    echo "skip $bin: not installed"
    continue
  fi
  # Don't spawn a second copy if it is already running.
  if pgrep -x "$bin" >/dev/null 2>&1; then
    echo "skip $bin: already running"
    continue
  fi
  if "$bin" >/dev/null 2>&1 & then
    echo "started $bin (pid $!)"
    started_any=true
  else
    # A failure here must never take the session down with it.
    echo "warn: $bin failed to start; continuing"
  fi
done

if ! $started_any; then
  echo "nothing started (no optional components installed)"
else
  echo ""
  echo "Launcher:  fuzzel --dmenu"
fi