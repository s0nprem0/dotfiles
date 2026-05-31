from network.common import (
    notify,
    wifi_enable, shut_lock,
    NOTIFY_TITLE, NOTIFY_OK, NOTIFY_BUSY,
    nmcli_run, error_menu, rofi_password,
)


def create_hotspot() -> None:
    ssid = rofi_password(f"{wifi_enable} Hotspot SSID:")
    if not ssid:
        return
    pwd = rofi_password(f"{shut_lock} Password (min 8 chars):")
    if not pwd:
        return
    if len(pwd) < 8:
        notify(title=NOTIFY_TITLE, message="Hotspot password must be at least 8 characters",
               urgency="critical")
        return
    notify(title=NOTIFY_TITLE, message=f"Creating hotspot '{ssid}'...", **NOTIFY_BUSY)
    r = nmcli_run(["device", "wifi", "hotspot", "ifname", "*", "ssid", ssid, "password", pwd])
    if r is None:
        error_menu("Failed to create hotspot")
        return
    notify(title=NOTIFY_TITLE, message=f"Hotspot '{ssid}' active", **NOTIFY_OK)
