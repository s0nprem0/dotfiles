from network.common import (
    notify, back_icon, BACK,
    wifi_enable, shut_lock,
    NOTIFY_TITLE, NOTIFY_OK, NOTIFY_BUSY,
    nmcli_run, error_menu, rofi_input, rofi_password,
)
from network import nm_dbus


def create_hotspot() -> None:
    ssid = rofi_input(f"{wifi_enable} Hotspot SSID:")
    if not ssid:
        return
    while True:
        pwd = rofi_password(f"{shut_lock} Password (min 8 chars):")
        if not pwd:
            return
        if len(pwd) >= 8:
            break
        notify(title=NOTIFY_TITLE, message="Password too short — must be at least 8 characters",
               urgency="critical")
    iface = nm_dbus.get_wifi_iface()
    if not iface:
        error_menu("No Wi-Fi interface found", "Cannot create hotspot without a Wi-Fi adapter")
        return
    notify(title=NOTIFY_TITLE, message=f"Creating hotspot '{ssid}'...", **NOTIFY_BUSY)
    r = nmcli_run(["device", "wifi", "hotspot", "ifname", iface, "ssid", ssid, "password", pwd], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to create hotspot", r.get("stderr") or r.get("message", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Hotspot '{ssid}' active", **NOTIFY_OK)


def is_hotspot_active() -> str | None:
    return nm_dbus.is_hotspot_active()


def stop_hotspot() -> None:
    name = is_hotspot_active()
    if not name:
        notify(title=NOTIFY_TITLE, message="No active hotspot", urgency="normal")
        return
    r = nmcli_run(["connection", "down", name], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to stop hotspot '{name}'", r.get("stderr") or r.get("message", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Hotspot '{name}' stopped", **NOTIFY_OK)
