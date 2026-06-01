from network.common import (
    notify, back_icon,
    ethernet_icon, disconnect_icon,
    NOTIFY_TITLE, NOTIFY_OK,
    nmcli_run, rofi_menu, error_menu,
)


def get_ethernet_info() -> dict:
    out = nmcli_run(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    if out is None:
        return {}
    for line in out.splitlines():
        dev, typ, state, conn = line.split(":", 3)
        if typ == "ethernet":
            ip = ""
            if state == "connected":
                ip_out = nmcli_run(["-t", "-f", "IP4.ADDRESS", "device", "show", dev])
                if ip_out:
                    ip = ip_out.split(":")[-1].strip()
            return {"device": dev, "state": state, "connection": conn, "ip": ip}
    return {}


def ethernet_menu() -> None:
    info = get_ethernet_info()
    iface = info.get("device", "N/A")
    state = info.get("state", "unavailable")
    ip = info.get("ip", "")

    options: list[str] = []
    status = f"{ethernet_icon}  {iface}"
    if state == "connected":
        status += f"  {ip}" if ip else "  (connected)"
    else:
        status += f"  ({state})"
    options.append(status)

    if state in ("connected", "connecting"):
        options.append(f"{disconnect_icon}  Disconnect Ethernet")
    elif state == "disconnected":
        options.append(f"{ethernet_icon}  Enable Ethernet")
    elif state == "unavailable":
        options.append(f"{ethernet_icon}  Enable Ethernet")
    if iface != "N/A":
        options.append(f"{ethernet_icon}  Disable Ethernet")
    options.append(f"{back_icon}  Back")

    chosen = rofi_menu(options, f" {ethernet_icon}")
    if not chosen:
        return

    if "Disconnect Ethernet" in chosen:
        conn_out = nmcli_run(["-t", "-f", "NAME,DEVICE", "connection", "show", "--active"])
        if conn_out:
            for line in conn_out.splitlines():
                name, dev = line.split(":", 1)
                if dev.strip() == iface:
                    r = nmcli_run(["connection", "down", "id", name])
                    if r is None:
                        error_menu(f"Failed to disconnect Ethernet ({name})")
                        ethernet_menu()
                        return
                    notify(title=NOTIFY_TITLE, message=f"Disconnected Ethernet ({name})", **NOTIFY_OK)
                    ethernet_menu()
                    return
        notify(title=NOTIFY_TITLE, message="No active Ethernet connection", urgency="low")
    elif "Enable Ethernet" in chosen:
        r = nmcli_run(["device", "connect", iface])
        if r is None:
            error_menu(f"Failed to enable Ethernet ({iface})")
            ethernet_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"Ethernet enabled ({iface})", **NOTIFY_OK)
        ethernet_menu()
    elif "Disable Ethernet" in chosen and iface != "N/A":
        r = nmcli_run(["device", "disconnect", iface])
        if r is None:
            error_menu(f"Failed to disable Ethernet ({iface})")
            ethernet_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"Ethernet disabled ({iface})", **NOTIFY_OK)
        ethernet_menu()
    elif "Back" in chosen:
        from network.main import main_menu
        main_menu()
