import subprocess
import os
import time

from network import common
from network.common import (
    wifi_enable, wifi_disable, ethernet_icon, vpn_icon, back_icon, BACK,
    rofi_menu, notify, error_menu,
    is_wifi_enabled, get_active_wifi, get_public_ip,
    get_active_vpn, nmcli_run, NOTIFY_TITLE, NOTIFY_OK,
)
from network.wifi import wifi_menu
from network.ethernet import ethernet_menu
from network.vpn import vpn_menu
from network.cache import cached


def _is_bt_blocked() -> bool:
    try:
        out = subprocess.run(["rfkill", "list", "bluetooth"], capture_output=True,
                             text=True, timeout=5).stdout
        return "blocked" in out
    except Exception:
        return True


def toggle_airplane_mode() -> None:
    wifi_on = is_wifi_enabled()
    bt_blocked = cached("bt_blocked", _is_bt_blocked, ttl=1)
    any_on = wifi_on or not bt_blocked

    if any_on:
        r = nmcli_run(["radio", "wifi", "off"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to disable Wi-Fi for airplane mode",
                       r.get("stderr") or r.get("message", ""))
            return
        subprocess.run(["rfkill", "block", "bluetooth"], capture_output=True, timeout=5)
        notify(title=NOTIFY_TITLE, message="✈ Airplane mode ON", **NOTIFY_OK)
    else:
        r = nmcli_run(["radio", "wifi", "on"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to enable Wi-Fi for airplane mode",
                       r.get("stderr") or r.get("message", ""))
            return
        subprocess.run(["rfkill", "unblock", "bluetooth"], capture_output=True, timeout=5)
        notify(title=NOTIFY_TITLE, message="✈ Airplane mode OFF", **NOTIFY_OK)


def main_menu() -> None:
    wifi_status = "On" if is_wifi_enabled() else "Off"
    active_wifi = get_active_wifi()
    wifi_detail = active_wifi if active_wifi else wifi_status
    active_vpn = get_active_vpn()
    vpn_detail = f"({active_vpn})" if active_vpn else ""

    # Public IP: non-blocking — read file cache, background refresh
    pub_ip = None
    try:
        mtime = os.path.getmtime(common.PUBLIC_IP_CACHE)
        if time.time() - mtime < 60:
            with open(common.PUBLIC_IP_CACHE) as f:
                pub_ip = f.read().strip() or None
    except Exception:
        pass
    if not pub_ip:
        import threading
        threading.Thread(target=get_public_ip, daemon=True).start()

    options: list[str] = []
    option_values: dict[str, str] = {}

    wifi_label = f"{wifi_enable}  Wi-Fi  ({wifi_detail})"
    options.append(wifi_label)
    option_values[wifi_label] = "wifi"

    eth_label = f"{ethernet_icon}  Ethernet"
    options.append(eth_label)
    option_values[eth_label] = "ethernet"

    vpn_label = f"{vpn_icon}  VPN  {vpn_detail}"
    options.append(vpn_label)
    option_values[vpn_label] = "vpn"

    wifi_on = is_wifi_enabled()
    bt_blocked = cached("bt_blocked", _is_bt_blocked, ttl=2)
    any_on = wifi_on or not bt_blocked
    ap_label = f"{'' if any_on else ''}  Airplane Mode: {'ON' if any_on else 'OFF'}"
    options.append(ap_label)
    option_values[ap_label] = "airplane"

    if pub_ip:
        ip_label = f"󰩟  Public IP:  {pub_ip}"
        options.append(ip_label)
        option_values[ip_label] = ""

    options.append(f"{back_icon}  Exit")
    option_values[options[-1]] = BACK

    chosen = rofi_menu(options, " 󰤨  Network")
    if not chosen:
        return

    selection = option_values.get(chosen)
    if not selection:
        return

    if selection == "wifi":
        wifi_menu()
    elif selection == "ethernet":
        ethernet_menu()
    elif selection == "vpn":
        vpn_menu()
    elif selection == "airplane":
        toggle_airplane_mode()
        main_menu()



