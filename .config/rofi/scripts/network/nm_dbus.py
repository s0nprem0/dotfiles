"""NetworkManager D-Bus wrapper using PyGObject NM bindings.

Falls back to nmcli_run if NM bindings fail (e.g. missing library).
"""
import os
import gi

gi.require_version('NM', '1.0')

_HAS_NM = False
_client = None

try:
    from gi.repository import NM, GLib
    _client = NM.Client.new(None)
    _HAS_NM = True
except Exception:
    pass

from utils import nmcli_run


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _setting_prop(conn, section: str, key: str) -> str:
    """Read a connection setting property via GObject props."""
    setting_map = {
        "connection": "get_setting_connection",
        "802-11-wireless": "get_setting_wireless",
        "802-11-wireless-security": "get_setting_wireless_security",
        "ipv4": "get_setting_ip4_config",
        "ipv6": "get_setting_ip6_config",
        "proxy": "get_setting_proxy",
    }
    getter = setting_map.get(section)
    if not getter:
        return ""
    setting = getattr(conn, getter)()
    if not setting:
        return ""
    py_key = key.replace("-", "_")
    try:
        val = getattr(setting.props, py_key)
        if val is None:
            return ""
        if isinstance(val, bool):
            return "yes" if val else "no"
        if isinstance(val, GLib.Bytes):
            return val.get_data().decode("utf-8", errors="replace") if val else ""
        if isinstance(val, list):
            return ", ".join(str(v) for v in val)
        return str(val)
    except AttributeError:
        return ""


def _ap_security(ap) -> str:
    flags = ap.get_flags()
    wpa = ap.get_wpa_flags()
    rsn = ap.get_rsn_flags()
    if wpa or rsn:
        return "WPA"
    return "WEP" if flags else ""


# ─── Public API ──────────────────────────────────────────────────────────────
# Each function returns the same type as its nmcli_run equivalent
# so they're drop-in replacements.

def wifi_enabled() -> bool:
    if _HAS_NM:
        return _client.wireless_get_enabled()
    res = nmcli_run(["-f", "WIFI", "g"])
    return res is not None and "enabled" in res


def set_wifi_enabled(enabled: bool) -> bool:
    if _HAS_NM:
        _client.wireless_set_enabled(enabled)
        return True
    r = nmcli_run(["radio", "wifi", "on" if enabled else "off"])
    return r is not None


def get_connectivity() -> str:
    if _HAS_NM:
        c = _client.get_connectivity()
        return {0: "unknown", 1: "none", 2: "portal", 3: "limited", 4: "full"}.get(c, "unknown")
    res = nmcli_run(["networking", "connectivity", "check"])
    return res.strip() if res else "unknown"


def get_active_wifi() -> str | None:
    if _HAS_NM:
        for ac in _client.get_active_connections():
            if ac.get_connection_type() == "802-11-wireless":
                return ac.get_id()
        return None
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if res is None:
        return None
    for line in res.splitlines():
        name, typ = line.split(":", 1)
        if typ == "wireless":
            return name
    return None


def saved_wifi_list() -> list[str]:
    if _HAS_NM:
        return [c.get_id() for c in _client.get_connections()
                if c.get_connection_type() == "802-11-wireless"]
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if res is None:
        return []
    return [c.split(":", 1)[0] for c in res.splitlines() if c.endswith("wireless")]


def trigger_scan() -> bool:
    """Request a Wi-Fi scan on all wifi devices (non-blocking). Returns True if triggered."""
    if not _HAS_NM:
        return False
    for dev in _client.get_devices():
        if dev.get_device_type() == NM.DeviceType.WIFI:
            try:
                dev.request_scan_simple({})
            except Exception:
                pass
    return True


def list_wifi(no_rescan: bool = True) -> dict:
    """Returns dict of ssid -> {ssid, security, signal, saved, visible}."""
    if _HAS_NM:
        saved = saved_wifi_list()
        networks = {}
        for dev in _client.get_devices():
            if dev.get_device_type() != NM.DeviceType.WIFI:
                continue
            if not no_rescan:
                try:
                    dev.request_scan_simple({})
                except Exception:
                    pass
            for ap in dev.get_access_points():
                s = ap.get_ssid()
                if s is None:
                    continue
                ssid = s.get_data().decode("utf-8", errors="replace")
                if not ssid:
                    continue
                sec = _ap_security(ap)
                sig = ap.get_strength()
                networks[ssid] = {
                    "ssid": ssid, "security": sec, "signal": sig,
                    "saved": ssid in saved, "visible": True,
                }
        return networks
    # Fallback to nmcli
    saved = saved_wifi_list()
    cmd = ["-t", "-f", "SECURITY,SSID,SIGNAL", "device", "wifi", "list"]
    if no_rescan:
        cmd += ["--rescan", "no"]
    res = nmcli_run(cmd)
    if res is None:
        return {}
    networks = {}
    for line in res.splitlines():
        parts = line.split(":")
        if len(parts) < 3:
            continue
        security = parts[0]
        signal = int(parts[-1]) if parts[-1].isdigit() else 0
        ssid = ":".join(parts[1:-1])
        if ssid:
            networks[ssid] = {
                "ssid": ssid, "security": security, "signal": signal,
                "saved": ssid in saved, "visible": True,
            }
    return networks


def get_connection_prop(ssid: str, prop: str) -> str:
    """Get a dotted connection property like 'connection.autoconnect'."""
    if _HAS_NM:
        for c in _client.get_connections():
            if c.get_id() == ssid:
                section, _, key = prop.partition(".")
                return _setting_prop(c, section, key)
        return ""
    res = nmcli_run(["connection", "show", "id", ssid])
    if res is None:
        return ""
    for line in res.splitlines():
        if line.startswith(f"{prop}:"):
            return line.split(":", 1)[1].strip()
    return ""


def get_dns_servers(ssid: str) -> list[str]:
    if _HAS_NM:
        for c in _client.get_connections():
            if c.get_id() == ssid:
                ip4 = c.get_setting_ip4_config()
                if ip4:
                    return [str(d) for d in ip4.props.dns]
        return []
    dns = get_connection_prop(ssid, "ipv4.dns")  # fallback -> nmcli
    return [s.strip() for s in dns.split(",") if s.strip()]


def vpn_list() -> list[str]:
    if _HAS_NM:
        return [c.get_id() for c in _client.get_connections()
                if c.get_connection_type() == "vpn"]
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if out is None:
        return []
    return [line.split(":")[0] for line in out.splitlines() if line.endswith(":vpn")]


def get_active_vpn() -> str | None:
    if _HAS_NM:
        for ac in _client.get_active_connections():
            if ac.get_connection_type() == "vpn":
                return ac.get_id()
        return None
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if out is None:
        return None
    for line in out.splitlines():
        name, typ = line.split(":", 1)
        if typ == "vpn":
            return name
    return None


def get_wifi_iface() -> str | None:
    """Get the Wi-Fi interface name."""
    if _HAS_NM:
        for d in _client.get_devices():
            if d.get_device_type() == NM.DeviceType.WIFI:
                return d.get_iface()
        return None
    out = nmcli_run(["-t", "-f", "DEVICE,TYPE", "device"])
    if out is None:
        return None
    for line in out.splitlines():
        dev, typ = line.split(":", 1)
        if typ == "wifi":
            return dev
    return None


def get_device_info(iface: str) -> dict:
    """Returns {mac, ip, gateway, dns, speed} for a device by interface name."""
    if _HAS_NM:
        for d in _client.get_devices():
            if d.get_iface() != iface:
                continue
            info: dict[str, str] = {"mac": "", "ip": "", "gateway": "", "dns": "", "speed": ""}
            # Permanent MAC from the hardware address
            if hasattr(d, "get_permanent_hw_address"):
                info["mac"] = d.get_permanent_hw_address() or ""
            if not info["mac"] and hasattr(d, "get_hw_address"):
                info["mac"] = d.get_hw_address() or ""
            if d.get_state() >= NM.DeviceState.ACTIVATED:
                ip4 = d.get_ip4_config()
                if ip4:
                    addrs = ip4.get_addresses()
                    if addrs:
                        info["ip"] = str(addrs[0].get_address())
                    info["gateway"] = ip4.get_gateway() or ""
                    dns_list = [str(n) for n in ip4.get_nameservers()]
                    info["dns"] = ", ".join(dns_list)
            if hasattr(d, "get_speed"):
                spd = d.get_speed()
                info["speed"] = str(spd) if spd else ""
            return info
        return {}
    out = nmcli_run(["-t", "-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.SPEED",
                     "device", "show", iface])
    if out is None:
        return {}
    info = {}
    for line in out.splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k = k.replace("GENERAL.", "").replace("IP4.", "").split("[")[0]
        if k == "HWADDR":
            info["mac"] = v.strip()
        elif k == "ADDRESS":
            info["ip"] = v.strip()
        elif k == "GATEWAY":
            info["gateway"] = v.strip()
        elif k == "DNS":
            info["dns"] = v.strip()
        elif k == "SPEED":
            info["speed"] = v.strip()
    return info


def _freq_to_channel(freq: int) -> int:
    if freq >= 2412 and freq <= 2484:
        return (freq - 2407) // 5
    if freq >= 5170 and freq <= 5825:
        return (freq - 5000) // 5
    return 0


def get_wifi_ap_info(ssid: str) -> dict | None:
    """Returns {channel, frequency, rate, signal, security, bssid} for a given SSID."""
    if _HAS_NM:
        for d in _client.get_devices():
            if d.get_device_type() != NM.DeviceType.WIFI:
                continue
            for ap in d.get_access_points():
                s = ap.get_ssid()
                if s is None:
                    continue
                name = s.get_data().decode("utf-8", errors="replace")
                if name != ssid:
                    continue
                freq = ap.get_frequency()
                return {
                    "channel": _freq_to_channel(freq),
                    "frequency": str(freq),
                    "rate": str(ap.get_max_bitrate()),
                    "signal": ap.get_strength(),
                    "security": _ap_security(ap),
                    "bssid": ap.get_bssid() or "",
                }
        return None
    out = nmcli_run(["-t", "-f", "SSID,SECURITY,SIGNAL,BARS,CHAN,FREQ,RATE",
                     "device", "wifi", "list", "--rescan", "no"])
    if out is None:
        return None
    for line in out.splitlines():
        if not line.strip():
            continue
        parts = line.split(":")
        if len(parts) < 7:
            continue
        name = parts[0]
        if name != ssid:
            continue
        return {
            "signal": int(parts[2]) if parts[2].isdigit() else 0,
            "channel": parts[4],
            "frequency": parts[5],
            "rate": parts[6],
            "security": parts[1],
            "bssid": "",
        }
    return None


def is_hotspot_active() -> str | None:
    """Returns the hotspot connection name if active, None otherwise."""
    if _HAS_NM:
        for ac in _client.get_active_connections():
            if ac.get_connection_type() == "hotspot":
                return ac.get_id()
        return None
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if out is None:
        return None
    for line in out.splitlines():
        name, typ = line.split(":", 1)
        if typ == "hotspot":
            return name
    return None


def ethernet_info() -> dict:
    """Returns {device, state, connection, ip} for the first ethernet device."""
    if _HAS_NM:
        for d in _client.get_devices():
            if d.get_device_type() != NM.DeviceType.ETHERNET:
                continue
            info = {
                "device": d.get_iface(),
                "state": {0: "unknown", 10: "unmanaged", 20: "unavailable",
                          30: "disconnected", 40: "connecting", 50: "connected"} \
                         .get(d.get_state(), f"state-{d.get_state()}"),
                "connection": d.get_active_connection().get_id() if d.get_active_connection() else "",
                "ip": "",
            }
            # Get IP via the device's ip4 config
            if d.get_state() >= NM.DeviceState.ACTIVATED:
                ip4 = d.get_ip4_config()
                if ip4:
                    addrs = ip4.get_addresses()
                    if addrs:
                        info["ip"] = addrs[0].get_address()
            return info
        return {}
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
