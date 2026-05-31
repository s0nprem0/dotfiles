from network.common import (
    notify, back_icon,
    disconnect_icon, vpn_icon,
    NOTIFY_TITLE, NOTIFY_OK,
    nmcli_run, rofi_menu, error_menu,
    get_vpn_list, get_active_vpn,
)


def vpn_menu() -> None:
    notify(title=NOTIFY_TITLE, message="Loading VPN connections...", expire_time=2_000)

    vpns = get_vpn_list()
    active_vpn = get_active_vpn()
    options: list[str] = []

    if active_vpn:
        options.append(f"{disconnect_icon}  Disconnect VPN ({active_vpn})")

    for vpn in vpns:
        if vpn != active_vpn:
            options.append(f"{vpn_icon}  Connect {vpn}")

    if not options:
        notify(title=NOTIFY_TITLE, message="No VPN connections configured", urgency="low")
        return

    options.append(f"{back_icon}  Back")

    chosen = rofi_menu(options, f" {vpn_icon}")
    if not chosen:
        return

    if "Disconnect VPN" in chosen:
        vpn_name = chosen.split("(")[1].rstrip(")")
        r = nmcli_run(["connection", "down", "id", vpn_name])
        if r is None:
            error_menu(f"Failed to disconnect VPN ({vpn_name})")
            vpn_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"VPN disconnected ({vpn_name})", **NOTIFY_OK)
        vpn_menu()
    elif "Connect" in chosen:
        vpn_name = chosen.split("Connect ")[1]
        r = nmcli_run(["connection", "up", "id", vpn_name])
        if r is None:
            error_menu(f"Failed to connect VPN ({vpn_name})")
            vpn_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"VPN connected ({vpn_name})", **NOTIFY_OK)
        vpn_menu()
    elif "Back" in chosen:
        from network.main import main_menu
        main_menu()
