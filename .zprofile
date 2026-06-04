if [ -z "${WAYLAND_DISPLAY}" ] && [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    if command -v uwsm >/dev/null 2>&1; then
        exec uwsm start hyprland.desktop
    else
        exec Hyprland
    fi
fi
