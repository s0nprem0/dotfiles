import re
from typing import Optional

from network.common import (
    notify, back_icon, BACK,
    shut_lock, open_lock, wifi_enable, wifi_disable, wifi_known,
    connect_icon, forget_icon, disconnect_icon, hidden_icon,
    NOTIFY_TITLE, NOTIFY_OK, NOTIFY_BUSY,
    WifiNetwork,
    TOGGLE_WIFI, CONNECT, FORGET, DISCONNECT, HIDDEN, RESCAN,
    HOTSPOT, STOP_HOTSPOT, SAVED, POWERSAVE,
    signal_bars, nmcli_run,
    rofi_menu, error_menu, confirm_menu, rofi_input, rofi_password,
    is_wifi_enabled, get_saved_networks, get_active_wifi,
    list_wifi_networks, get_connection_prop,
    get_power_save, check_connectivity,
)
from network.cache import cached, invalidate


# ─── Wi-Fi Toggle ───────────────────────────────────────────────────────────

def toggle_wifi() -> None:
    if is_wifi_enabled():
        r = nmcli_run(["radio", "wifi", "off"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to disable Wi-Fi", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message="Wi-Fi disabled", **NOTIFY_OK)
    else:
        r = nmcli_run(["radio", "wifi", "on"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to enable Wi-Fi", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message="Wi-Fi enabled", **NOTIFY_OK)


# ─── Connection Actions ─────────────────────────────────────────────────────

def connect_existing_network(ssid: str) -> bool:
    notify(title=NOTIFY_TITLE, message=f"Connecting to {ssid}...", **NOTIFY_BUSY)
    result = nmcli_run(["connection", "up", "id", ssid], timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to {ssid}", errd)
        return False
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")
    return True


def connect_new_network(ssid: str, security: Optional[str]) -> bool:
    cmd = ["device", "wifi", "connect", ssid]
    if security and security.startswith("WPA"):
        pwd = rofi_password(f"{shut_lock} Password for {ssid}:")
        if not pwd:
            return False
        cmd += ["password", pwd]
    notify(title=NOTIFY_TITLE, message=f"Connecting to {ssid}...", **NOTIFY_BUSY)
    result = nmcli_run(cmd, timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to {ssid}", errd)
        return False
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")
    return True


def disconnect_wifi() -> None:
    active = get_active_wifi()
    if active:
        r = nmcli_run(["connection", "down", "id", active], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu(f"Failed to disconnect from {active}", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message=f"Disconnected from {active}", **NOTIFY_OK)
        invalidate("active_ssid")


def connect_hidden_network() -> None:
    ssid = rofi_password(f"{hidden_icon} Hidden SSID:")
    if not ssid:
        return
    pwd = rofi_password(f"{shut_lock} Password (leave empty for open):")
    cmd = ["device", "wifi", "connect", ssid, "hidden", "yes"]
    if pwd:
        cmd += ["password", pwd]
    notify(title=NOTIFY_TITLE, message="Connecting to hidden SSID...", **NOTIFY_BUSY)
    result = nmcli_run(cmd, timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to hidden SSID {ssid}", errd)
        return
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")


def forget_network(ssid: str) -> bool:
    result = nmcli_run(["connection", "delete", "id", ssid], want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        error_menu(f"Failed to forget network {ssid}", result.get("stderr") or result.get("message", ""))
        return False
    notify(title=NOTIFY_TITLE, message=f"Forgot network: {ssid}", **NOTIFY_OK)
    return True


# ─── Connection Management ──────────────────────────────────────────────────

def is_auto_connect(ssid: str) -> bool:
    res = nmcli_run(["connection", "show", "id", ssid])
    if res is None:
        return True
    for line in res.splitlines():
        if line.startswith("connection.autoconnect:"):
            return line.split(":", 1)[1].strip() == "yes"
    return True


def toggle_autoconnect(ssid: str) -> None:
    current = is_auto_connect(ssid)
    new_val = "no" if current else "yes"
    r = nmcli_run(["connection", "modify", "id", ssid, "connection.autoconnect", new_val], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to toggle auto-connect for {ssid}", r.get("stderr") or r.get("message", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Auto-connect: {'ON' if new_val == 'yes' else 'OFF'} for {ssid}",
           **NOTIFY_OK)


def toggle_power_save() -> None:
    iface = _get_wifi_iface()
    if not iface:
        return
    current = get_power_save()
    if current is None:
        error_menu("Could not read power save state")
        return
    new_val = "off" if current else "on"
    r = nmcli_run(["radio", "wifi", "power", "save", new_val], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to toggle power saving", r.get("stderr") or r.get("message", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Power saving: {'ON' if new_val == 'on' else 'OFF'}",
           **NOTIFY_OK)


def _get_wifi_iface() -> Optional[str]:
    res = nmcli_run(["-t", "-f", "DEVICE,TYPE", "device"])
    if res is None:
        return None
    for line in res.splitlines():
        dev, typ = line.split(":", 1)
        if typ == "wifi":
            return dev
    return None


# ─── Band / MAC / Priority ────────────────────────────────────────────────

def get_band_preference(ssid: str) -> str:
    val = get_connection_prop(ssid, "802-11-wireless.band")
    return val if val else "auto"


def cycle_band(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_band_preference(ssid)
    order = {"auto": "a", "a": "bg", "bg": "auto"}
    new_band = order.get(current, "auto")
    r = nmcli_run(["connection", "modify", "id", ssid, "802-11-wireless.band", new_band], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set band preference", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    label = {"auto": "Auto", "a": "5 GHz", "bg": "2.4 GHz"}
    notify(title=NOTIFY_TITLE, message=f"Band: {label.get(new_band, new_band)} for {ssid}",
           **NOTIFY_OK)
    show_network_actions(network)


def get_mac_mode(ssid: str) -> str:
    val = get_connection_prop(ssid, "802-11-wireless.cloned-mac-address")
    return val if val else "permanent"


_MAC_RE = r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'


def _is_custom_mac(val: str) -> bool:
    return bool(re.match(_MAC_RE, val))


def cycle_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_mac_mode(ssid)
    if _is_custom_mac(current):
        new_mode = "permanent"
    else:
        order = {"permanent": "random", "random": "stable", "stable": "permanent"}
        new_mode = order.get(current, "permanent")
    r = nmcli_run(["connection", "modify", "id", ssid, "802-11-wireless.cloned-mac-address", new_mode], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set MAC mode", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC: {new_mode} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def set_custom_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_mac_mode(ssid)
    default = current if _is_custom_mac(current) else ""
    raw = rofi_input(f"  MAC for {ssid}", default)
    if not raw:
        show_network_actions(network)
        return
    mac = raw.strip().lower()
    if not re.match(_MAC_RE, mac):
        error_menu("Invalid MAC — use format 00:11:22:33:44:55")
        show_network_actions(network)
        return
    r = nmcli_run(["connection", "modify", "id", ssid,
                    "802-11-wireless.cloned-mac-address", mac], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to set MAC for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC set to {mac} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def reset_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    if not confirm_menu(f"Reset MAC to permanent for {ssid}?"):
        show_network_actions(network)
        return
    r = nmcli_run(["connection", "modify", "id", ssid,
                    "802-11-wireless.cloned-mac-address", ""], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to reset MAC for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC reset to permanent for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def get_autoconnect_priority(ssid: str) -> int:
    val = get_connection_prop(ssid, "connection.autoconnect-priority")
    return int(val) if val and val.isdigit() else 0


def cycle_priority(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_autoconnect_priority(ssid)
    values = [0, 5, 10, 20, 50, 100]
    idx = (values.index(current) + 1) % len(values) if current in values else 0
    new_prio = values[idx]
    r = nmcli_run(["connection", "modify", "id", ssid, "connection.autoconnect-priority", str(new_prio)], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set priority", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"Priority: {new_prio} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


# ─── DNS ─────────────────────────────────────────────────────────────────────

def get_dns_servers(ssid: str) -> list[str]:
    res = nmcli_run(["connection", "show", "id", ssid])
    if res is None:
        return []
    for line in res.splitlines():
        if line.startswith("ipv4.dns:"):
            val = line.split(":", 1)[1].strip()
            return [s.strip() for s in val.split(",") if s.strip()]
    return []


def set_dns_servers(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_dns_servers(ssid)
    default = ", ".join(current) if current else ""
    raw = rofi_input(f"  DNS for {ssid} (comma-sep, empty=auto):", default)
    if raw == default:
        show_network_actions(network)
        return
    servers = [s.strip() for s in raw.split(",") if s.strip()]
    if servers:
        dns_str = " ".join(servers)
        r = nmcli_run(["connection", "modify", "id", ssid, "ipv4.dns", dns_str,
                        "ipv4.ignore-auto-dns", "yes"], want_result=True)
    else:
        r = nmcli_run(["connection", "modify", "id", ssid, "ipv4.dns", "",
                        "ipv4.ignore-auto-dns", "no"], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to set DNS for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    label = " ".join(servers) if servers else "auto"
    notify(title=NOTIFY_TITLE, message=f"DNS: {label} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


# ─── Connection Details ─────────────────────────────────────────────────────

def show_connection_details(network: WifiNetwork) -> None:
    res = nmcli_run(["connection", "show", "id", network.ssid])
    if res is None:
        error_menu("Failed to fetch details")
        show_network_actions(network)
        return

    opts = [f"SSID:  {network.ssid}"]
    iface = ""
    for line in res.splitlines():
        if line.startswith("connection.interface-name:"):
            iface = line.split(":", 1)[1].strip()
        elif line.startswith("connection.autoconnect:"):
            opts.append(f"Auto-connect:  {line.split(':', 1)[1].strip()}")
        elif line.startswith("ipv4.method:"):
            opts.append(f"IP method:  {line.split(':', 1)[1].strip()}")

    if iface:
        opts.append(f"Interface:  {iface}")
        dev = nmcli_run(["-t", "-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.SPEED",
                        "device", "show", iface])
        if dev:
            for line in dev.splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    k = k.replace("GENERAL.", "").replace("IP4.", "").split("[")[0]
                    if k == "HWADDR":
                        opts.append(f"MAC:  {v}")
                    elif k == "ADDRESS":
                        opts.append(f"IP:  {v}")
                    elif k == "GATEWAY":
                        opts.append(f"Gateway:  {v}")
                    elif k == "DNS":
                        opts.append(f"DNS:  {v}")
                    elif k == "SPEED":
                        opts.append(f"Speed:  {v}")

    opts.append(f"{back_icon}  Back")
    rofi_menu(opts, prompt=f"{wifi_enable} Details", selected_row=len(opts) - 1)
    show_network_actions(network)


def show_wifi_info_menu(network: WifiNetwork) -> None:
    res = nmcli_run(["-t", "-f", "SSID,SECURITY,SIGNAL,BARS,CHAN,FREQ,RATE",
                     "device", "wifi", "list", "--rescan", "no"])
    if res is None:
        error_menu("Failed to fetch Wi-Fi info")
        return

    extra_info = {}
    for line in res.splitlines():
        if not line.strip():
            continue
        parts = line.split(":")
        if len(parts) < 7:
            continue
        rate = parts[-1]
        freq = parts[-2]
        chan = parts[-3]
        bars = parts[-4]
        sig_str = parts[-5]
        sec = parts[-6]
        line_ssid = ":".join(parts[:-6])
        if line_ssid == network.ssid and sig_str.isdigit():
            extra_info = {"signal": f"{sig_str}%", "bars": bars, "security": sec,
                          "channel": chan, "frequency": freq, "rate": rate}
            break

    opts = [f"SSID:  {network.ssid}"]
    if extra_info:
        opts.append(f"Security:  {extra_info['security'] or 'Open'}")
        opts.append(f"Signal:  {extra_info['signal']}  {extra_info['bars']}")
        opts.append(f"Channel:  {extra_info['channel']}  ({extra_info['frequency']})")
        opts.append(f"Rate:  {extra_info['rate']}")
    else:
        opts.append(f"Security:  {network.security or 'Open'}")
        opts.append(f"Signal:  {network.signal}%  {signal_bars(network.signal)}")
    if network.saved:
        opts.append(f"Saved:  Yes")
    opts.append(f"{back_icon}  Back")
    rofi_menu(opts, prompt=f"{wifi_enable} Info", selected_row=len(opts) - 1)


# ─── Network Action Menu ────────────────────────────────────────────────────

def show_network_actions(network: WifiNetwork, active_ssid: Optional[str] = None) -> None:
    if active_ssid is None:
        active_ssid = cached("active_ssid", get_active_wifi, ttl=2)

    is_connected = network.ssid == active_ssid
    title = f"{wifi_enable}  {network.ssid}"
    if network.saved:
        title += f"  {wifi_known}"
    if is_connected:
        title += "  "

    actions: dict[str, str] = {}
    if not is_connected:
        actions[f"{connect_icon}  {CONNECT}"] = "connect"
    actions[f"  Info"] = "info"
    if network.saved:
        actions[f"{forget_icon}  {FORGET}"] = "forget"
    if is_connected:
        actions[f"  Details"] = "details"
    if network.saved:
        auto = is_auto_connect(network.ssid)
        icon = "" if auto else ""
        actions[f"{icon}  Auto-connect: {'On' if auto else 'Off'}"] = "autoconnect"
        band = get_band_preference(network.ssid)
        bl = {"auto": "Auto", "a": "5 GHz", "bg": "2.4 GHz"}
        actions[f"  Band: {bl.get(band, band)}"] = "band"
        mac = get_mac_mode(network.ssid)
        label = "custom" if _is_custom_mac(mac) else mac
        actions[f"  MAC: {label}"] = "mac"
        actions["  Set custom MAC"] = "setmac"
        if _is_custom_mac(mac):
            actions["  Reset MAC to permanent"] = "resetmac"
        prio = get_autoconnect_priority(network.ssid)
        actions[f"  Priority: {prio}"] = "priority"
        dns = get_dns_servers(network.ssid)
        dns_label = " ".join(dns) if dns else "auto"
        actions[f"  DNS: {dns_label}"] = "dns"
    actions[f"{back_icon}  {BACK}"] = "back"

    chosen = rofi_menu(list(actions.keys()), title)
    if not chosen:
        return

    action = actions.get(chosen)

    if action == "back":
        wifi_menu()
    elif action == "connect":
        if network.saved:
            ok = connect_existing_network(network.ssid)
        else:
            ok = connect_new_network(network.ssid, network.security)
        if ok:
            wifi_menu()
        else:
            show_network_actions(network)
    elif action == "forget":
        if confirm_menu(f"{forget_icon} Forget {network.ssid}?"):
            ok = forget_network(network.ssid)
            if ok:
                wifi_menu()
            else:
                show_network_actions(network)
        else:
            show_network_actions(network)
    elif action == "info":
        show_wifi_info_menu(network)
        show_network_actions(network)
    elif action == "details":
        show_connection_details(network)
    elif action == "autoconnect":
        toggle_autoconnect(network.ssid)
        show_network_actions(network)
    elif action == "band":
        cycle_band(network)
    elif action == "mac":
        cycle_mac(network)
    elif action == "setmac":
        set_custom_mac(network)
    elif action == "resetmac":
        reset_mac(network)
    elif action == "priority":
        cycle_priority(network)
    elif action == "dns":
        set_dns_servers(network)


# ─── Saved Networks Menu ───────────────────────────────────────────────────

def saved_networks_menu() -> None:
    saved = [s for s in get_saved_networks() if s]
    if not saved:
        notify(title=NOTIFY_TITLE, message="No saved Wi-Fi networks", urgency="low")
        return

    active_ssid = cached("active_ssid", get_active_wifi, ttl=2)
    options = {}
    for ssid in saved:
        active_tag = " " if ssid == active_ssid else ""
        offline = "" if ssid == active_ssid else "  (offline)"
        options[f"{active_tag}{wifi_known}  {ssid}{offline}"] = ssid
    options[f"{back_icon}  Back"] = BACK

    chosen = rofi_menu(list(options.keys()), f"{wifi_known}  Saved Networks")
    if not chosen:
        return

    selection = options.get(chosen)
    if not selection:
        return

    if selection == BACK:
        return
    else:
        network = WifiNetwork(ssid=selection, security=None, signal=0,
                              saved=True, visible=selection in list_wifi_networks(no_rescan=True))
        show_network_actions(network)


# ─── Wi-Fi Menu ─────────────────────────────────────────────────────────────

def wifi_menu() -> None:
    wifi_on = cached("wifi_on", is_wifi_enabled, ttl=2)
    networks = cached("networks", lambda: list_wifi_networks() if wifi_on else {}, ttl=2)
    active_ssid = cached("active_ssid", get_active_wifi, ttl=2)

    if wifi_on and (not networks or "~scanning~" in networks):
        notify(title=NOTIFY_TITLE, message="Scanning for networks...", expire_time=6_000)
        networks = list_wifi_networks(no_rescan=False)
        active_ssid = get_active_wifi()
        invalidate("networks")
        invalidate("active_ssid")

    option_labels: list[str] = []
    option_values: dict[str, str] = {}
    active_rows: list[int] = []
    urgent_rows: list[int] = []

    if wifi_on:
        option_labels.append(f"{wifi_disable}  Disable Wi-Fi")
        option_values[option_labels[-1]] = TOGGLE_WIFI
        active_rows.append(len(option_labels) - 1)

        if active_ssid:
            option_labels.append(f"{disconnect_icon}  Disconnect from {active_ssid}")
            option_values[option_labels[-1]] = DISCONNECT
            active_rows.append(len(option_labels) - 1)

        option_labels.append(f"{hidden_icon}  Connect to Hidden Network")
        option_values[option_labels[-1]] = HIDDEN
        active_rows.append(len(option_labels) - 1)

        option_labels.append("󰋁  Create Hotspot")
        option_values[option_labels[-1]] = HOTSPOT
        active_rows.append(len(option_labels) - 1)

        from network.hotspot import is_hotspot_active
        if is_hotspot_active():
            option_labels.append("󰤂  Stop Hotspot")
            option_values[option_labels[-1]] = STOP_HOTSPOT
            active_rows.append(len(option_labels) - 1)

        option_labels.append(f"{wifi_known}  Saved Networks")
        option_values[option_labels[-1]] = SAVED
        active_rows.append(len(option_labels) - 1)

        option_labels.append("  Rescan")
        option_values[option_labels[-1]] = RESCAN
        active_rows.append(len(option_labels) - 1)

        ps = cached("power_save", get_power_save, ttl=5)
        if ps is not None:
            ps_icon = "" if ps else ""
            option_labels.append(f"{ps_icon}  Power Save: {'On' if ps else 'Off'}")
            option_values[option_labels[-1]] = POWERSAVE
            active_rows.append(len(option_labels) - 1)

        conn = cached("connectivity", check_connectivity, ttl=5)
        if conn in ("full", "limited", "portal", "none"):
            ci = {"full": "󰤨", "limited": "󰤢", "portal": "󰤦", "none": "󰤭"}
            option_labels.append(f"{ci.get(conn, '󰤯')}  Status: {conn}")
            option_values[option_labels[-1]] = "CONNINFO"
            urgent_rows.append(len(option_labels) - 1)
            if conn == "portal":
                option_labels.append("󰖐  Open Captive Portal Login")
                option_values[option_labels[-1]] = "OPEN_PORTAL"
                active_rows.append(len(option_labels) - 1)

        if "~scanning~" in networks:
            option_labels.append("󰓨  Scanning...")
            option_values[option_labels[-1]] = ""
        else:
            sorted_networks = sorted(
                networks.values(),
                key=lambda n: (not n.saved, -n.signal),
            )
            for n in sorted_networks:
                icon = wifi_known if n.saved else (
                    shut_lock if n.security and n.security.startswith("WPA") else open_lock
                )
                active_tag = f" " if n.ssid == active_ssid else ""
                label = f"{active_tag}{icon}  {signal_bars(n.signal)} {n.signal:>3}%  {n.ssid}"
                option_labels.append(label)
                option_values[label] = n.ssid
    else:
        option_labels.append(f"{wifi_enable}  Enable Wi-Fi")
        option_values[option_labels[-1]] = TOGGLE_WIFI

    option_labels.append(f"{back_icon}  Back")
    option_values[option_labels[-1]] = BACK

    chosen = rofi_menu(option_labels, f" {wifi_enable}",
                       active_rows=active_rows or None,
                       urgent_rows=urgent_rows or None)
    if not chosen:
        return

    if chosen.startswith("Error:"):
        return

    selection = option_values.get(chosen)
    if not selection:
        return

    if selection == TOGGLE_WIFI:
        toggle_wifi()
        wifi_menu()
    elif selection == BACK:
        from network.main import main_menu
        main_menu()
    elif selection == DISCONNECT:
        disconnect_wifi()
        wifi_menu()
    elif selection == HIDDEN:
        connect_hidden_network()
        wifi_menu()
    elif selection == HOTSPOT:
        from network.hotspot import create_hotspot
        create_hotspot()
        wifi_menu()
    elif selection == STOP_HOTSPOT:
        from network.hotspot import stop_hotspot
        stop_hotspot()
        wifi_menu()
    elif selection == SAVED:
        saved_networks_menu()
    elif selection == POWERSAVE:
        toggle_power_save()
        wifi_menu()
    elif selection == RESCAN:
        invalidate("networks")
        invalidate("active_ssid")
        notify(title=NOTIFY_TITLE, message="Started scanning in background...", expire_time=4000)
        wifi_menu()
    elif selection == "CONNINFO":
        wifi_menu()
    elif selection == "OPEN_PORTAL":
        import subprocess
        for url in ("http://detectportal.firefox.com/canonical.html",
                    "http://captive.apple.com",
                    "http://www.msftconnecttest.com"):
            subprocess.Popen(["xdg-open", url])
        wifi_menu()
    elif selection in networks and selection != "~scanning~":
        show_network_actions(networks[selection])
