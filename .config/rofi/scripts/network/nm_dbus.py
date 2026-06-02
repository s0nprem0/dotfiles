"""NetworkManager D-Bus wrapper using dbus-python.

Falls back to nmcli_run if dbus import fails.
Import + full query in ~55ms vs 170ms with gi.repository.NM.
"""
import dbus

from utils import nmcli_run

_HAS_DBUS = False
_bus = None
_props = None
_nm = None
_settings = None

try:
    _bus = dbus.SystemBus()
    _nm = _bus.get_object('org.freedesktop.NetworkManager',
                          '/org/freedesktop/NetworkManager')
    _props = dbus.Interface(_nm, 'org.freedesktop.DBus.Properties')
    _settings = _bus.get_object('org.freedesktop.NetworkManager',
                                '/org/freedesktop/NetworkManager/Settings')
    _HAS_DBUS = True
except Exception:
    pass

_NM_IFACE = 'org.freedesktop.NetworkManager'
_DEV_IFACE = 'org.freedesktop.NetworkManager.Device'
_WIFI_DEV_IFACE = 'org.freedesktop.NetworkManager.Device.Wireless'
_AP_IFACE = 'org.freedesktop.NetworkManager.AccessPoint'
_AC_IFACE = 'org.freedesktop.NetworkManager.Connection.Active'
_SETTINGS_IFACE = 'org.freedesktop.NetworkManager.Settings'
_CONN_IFACE = 'org.freedesktop.NetworkManager.Settings.Connection'
_IP4_IFACE = 'org.freedesktop.NetworkManager.IP4Config'

_NM_DEVICE_TYPE_WIFI = 2
_NM_DEVICE_TYPE_ETHERNET = 1
_NM_DEVICE_STATE_ACTIVATED = 50

# NM 802.11 mode enum (subset)
_NM_80211_MODE_AP = 3


def _g(iface: str, prop: str, obj=None) -> any:
    target = _props if obj is None else dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
    return target.Get(iface, prop)


def _p(obj) -> dbus.Interface:
    """Return org.freedesktop.DBus.Properties interface for an object."""
    return dbus.Interface(obj, 'org.freedesktop.DBus.Properties')


def _c(method: str, iface: str, obj=None, *args) -> any:
    target = dbus.Interface(obj or _nm, iface)
    return getattr(target, method)(*args)


def _ssid(ssid_bytes) -> str:
    if not ssid_bytes:
        return ""
    return bytes(ssid_bytes).decode("utf-8", errors="replace")


def _ap_security(flags: int, wpa: int, rsn: int) -> str:
    if wpa or rsn:
        return "WPA"
    return "WEP" if flags & 1 else ""


def _state_str(state: int) -> str:
    return {0: "unknown", 10: "unmanaged", 20: "unavailable",
            30: "disconnected", 40: "prepare", 50: "config",
            60: "need-auth", 70: "ip-config", 80: "ip-check",
            90: "secondaries", 100: "activated", 110: "deactivating",
            120: "failed"}.get(state, f"state-{state}")


def _freq_to_channel(freq: int) -> int:
    if 2412 <= freq <= 2484:
        return (freq - 2407) // 5
    if 5170 <= freq <= 5825:
        return (freq - 5000) // 5
    return 0


def _ip4_str(ip_int: int) -> str:
    ip_int = int(ip_int)
    return f"{ip_int & 0xFF}.{(ip_int >> 8) & 0xFF}.{(ip_int >> 16) & 0xFF}.{(ip_int >> 24) & 0xFF}"


# ─── Public API ──────────────────────────────────────────────────────────────


def wifi_enabled() -> bool:
    if _HAS_DBUS:
        return bool(_g(_NM_IFACE, 'WirelessEnabled'))
    res = nmcli_run(["-f", "WIFI", "g"])
    return res is not None and "enabled" in res


def set_wifi_enabled(enabled: bool) -> bool:
    if _HAS_DBUS:
        _props.Set(_NM_IFACE, 'WirelessEnabled', enabled)
        return True
    r = nmcli_run(["radio", "wifi", "on" if enabled else "off"])
    return r is not None


def get_connectivity() -> str:
    if _HAS_DBUS:
        v = _g(_NM_IFACE, 'Connectivity')
        return {1: "none", 2: "portal", 3: "limited", 4: "full"}.get(int(v), "unknown")
    res = nmcli_run(["networking", "connectivity", "check"])
    return res.strip() if res else "unknown"


def get_active_wifi() -> str | None:
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'ActiveConnections')
        if not paths:
            return None
        for p in paths:
            obj = _bus.get_object('org.freedesktop.NetworkManager', p)
            typ = _p(obj).Get(_AC_IFACE, 'Type')
            if typ == '802-11-wireless':
                return str(_p(obj).Get(_AC_IFACE, 'Id') or "")
        return None
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if res is None:
        return None
    for line in res.splitlines():
        name, typ = line.split(":", 1)
        if typ == "wireless":
            return name
    return None


def _all_connections():
    """Return list of (object_path, settings_dict) for all saved connections."""
    paths = _c('ListConnections', _SETTINGS_IFACE, _settings)
    if not paths:
        return []
    result = []
    for cp in paths:
        obj = _bus.get_object('org.freedesktop.NetworkManager', cp)
        settings = dbus.Interface(obj, _CONN_IFACE).GetSettings()
        result.append((cp, settings))
    return result


def saved_wifi_list() -> list[str]:
    if _HAS_DBUS:
        conns = _all_connections()
        return [str(s.get('connection', {}).get('id', '') or "")
                for _, s in conns
                if s.get('connection', {}).get('type') == '802-11-wireless']
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if res is None:
        return []
    return [c.split(":", 1)[0] for c in res.splitlines() if c.endswith("wireless")]


def trigger_scan() -> bool:
    if not _HAS_DBUS:
        return False
    paths = _g(_NM_IFACE, 'AllDevices')
    if not paths:
        return False
    triggered = False
    for dp in paths:
        dtype = _g(_DEV_IFACE, 'DeviceType',
                   _bus.get_object('org.freedesktop.NetworkManager', dp))
        if int(dtype) == _NM_DEVICE_TYPE_WIFI:
            try:
                dev = _bus.get_object('org.freedesktop.NetworkManager', dp)
                dbus.Interface(dev, _WIFI_DEV_IFACE).RequestScan({})
                triggered = True
            except Exception:
                pass
    return triggered


def list_wifi(no_rescan: bool = True) -> dict:
    if _HAS_DBUS:
        saved = saved_wifi_list()
        networks = {}
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return {}
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            dtype = _g(_DEV_IFACE, 'DeviceType', dev_obj)
            if int(dtype) != _NM_DEVICE_TYPE_WIFI:
                continue
            iface = str(_g(_DEV_IFACE, 'Interface', dev_obj) or "")
            if not no_rescan:
                try:
                    dbus.Interface(dev_obj, _WIFI_DEV_IFACE).RequestScan({})
                except Exception:
                    pass
            ap_paths = _c('GetAllAccessPoints', _WIFI_DEV_IFACE, dev_obj)
            if not ap_paths:
                continue
            for ap_path in ap_paths:
                ap_obj = _bus.get_object('org.freedesktop.NetworkManager', ap_path)
                ssid = _ssid(_p(ap_obj).Get(_AP_IFACE, 'Ssid'))
                if not ssid:
                    continue
                flags = int(_p(ap_obj).Get(_AP_IFACE, 'Flags'))
                wpa = int(_p(ap_obj).Get(_AP_IFACE, 'WpaFlags'))
                rsn = int(_p(ap_obj).Get(_AP_IFACE, 'RsnFlags'))
                signal = int(_p(ap_obj).Get(_AP_IFACE, 'Strength'))
                networks[ssid] = {
                    "ssid": ssid,
                    "security": _ap_security(flags, wpa, rsn),
                    "signal": signal,
                    "saved": ssid in saved,
                    "visible": True,
                    "device": iface,
                }
        return networks
    saved = saved_wifi_list()
    # Get list of Wi-Fi interfaces to run per-device scans
    ifaces = [d["iface"] for d in get_wifi_ifaces()]
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
            device = ""
            if len(ifaces) == 1:
                device = ifaces[0]
            networks[ssid] = {
                "ssid": ssid, "security": security, "signal": signal,
                "saved": ssid in saved, "visible": True,
                "device": device,
            }
    return networks


def _conn_settings_by_ssid(ssid: str) -> dict | None:
    conns = _all_connections()
    for _, s in conns:
        c = s.get('connection', {})
        if c.get('id') == ssid:
            return s
    return None


def get_connection_prop(ssid: str, prop: str) -> str:
    if _HAS_DBUS:
        settings = _conn_settings_by_ssid(ssid)
        if not settings:
            return ""
        section, _, key = prop.partition(".")
        sec = settings.get(section, {})
        val = sec.get(key)
        if val is None:
            return ""
        if isinstance(val, bool) or isinstance(val, dbus.Boolean):
            return "yes" if val else "no"
        if isinstance(val, (list, dbus.Array)):
            return ", ".join(str(v) for v in val)
        if isinstance(val, bytes):
            return val.decode("utf-8", errors="replace")
        return str(val)
    res = nmcli_run(["connection", "show", "id", ssid])
    if res is None:
        return ""
    for line in res.splitlines():
        if line.startswith(f"{prop}:"):
            return line.split(":", 1)[1].strip()
    return ""


def get_dns_servers(ssid: str) -> list[str]:
    if _HAS_DBUS:
        settings = _conn_settings_by_ssid(ssid)
        if not settings:
            return []
        ip4 = settings.get('ipv4', {})
        dns_list = ip4.get('dns', [])
        return [_ip4_str(d) for d in dns_list if d]
    dns = get_connection_prop(ssid, "ipv4.dns")
    return [s.strip() for s in dns.split(",") if s.strip()]


def vpn_list() -> list[str]:
    if _HAS_DBUS:
        conns = _all_connections()
        return [str(s.get('connection', {}).get('id', '') or "")
                for _, s in conns
                if s.get('connection', {}).get('type') == 'vpn']
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if out is None:
        return []
    return [line.split(":")[0] for line in out.splitlines() if line.endswith(":vpn")]


def get_active_vpn() -> str | None:
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'ActiveConnections')
        if not paths:
            return None
        for p in paths:
            obj = _bus.get_object('org.freedesktop.NetworkManager', p)
            typ = _p(obj).Get(_AC_IFACE, 'Type')
            if typ == 'vpn':
                return str(_p(obj).Get(_AC_IFACE, 'Id') or "")
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
    ifaces = get_wifi_ifaces()
    return ifaces[0]["iface"] if ifaces else None


def get_wifi_ifaces() -> list[dict]:
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return []
        result = []
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            dtype = _g(_DEV_IFACE, 'DeviceType', dev_obj)
            if int(dtype) != _NM_DEVICE_TYPE_WIFI:
                continue
            iface = str(_g(_DEV_IFACE, 'Interface', dev_obj) or "")
            if not iface:
                continue
            state = int(_g(_DEV_IFACE, 'State', dev_obj))
            mac = str(_g(_DEV_IFACE, 'HwAddress', dev_obj) or "")
            info: dict[str, str | int] = {
                "iface": iface,
                "state": _state_str(state),
                "mac": mac,
                "ip": "",
                "active_ssid": "",
                "signal": 0,
            }
            if state >= _NM_DEVICE_STATE_ACTIVATED:
                ac_path = _g(_DEV_IFACE, 'ActiveConnection', dev_obj)
                if ac_path and ac_path != '/':
                    ac_obj = _bus.get_object('org.freedesktop.NetworkManager', ac_path)
                    info["active_ssid"] = str(_p(ac_obj).Get(_AC_IFACE, 'Id') or "")
                ip4_path = _g(_DEV_IFACE, 'Ip4Config', dev_obj)
                if ip4_path and ip4_path != '/':
                    ip4_obj = _bus.get_object('org.freedesktop.NetworkManager', ip4_path)
                    addrs = _g(_IP4_IFACE, 'Addresses', ip4_obj)
                    if addrs:
                        info["ip"] = _ip4_str(addrs[0][0])
                try:
                    ap_paths = _c('GetAllAccessPoints', _WIFI_DEV_IFACE, dev_obj)
                    if ap_paths:
                        best = 0
                        for ap_path in ap_paths:
                            ap_obj = _bus.get_object('org.freedesktop.NetworkManager', ap_path)
                            sig = int(_p(ap_obj).Get(_AP_IFACE, 'Strength'))
                            best = max(best, sig)
                        info["signal"] = best
                except Exception:
                    pass
            result.append(info)
        return result
    out = nmcli_run(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"])
    if out is None:
        return []
    result = []
    for line in out.splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[1] == "wifi":
            dev = parts[0]
            state = parts[2]
            conn = parts[3] if len(parts) > 3 else ""
            info: dict[str, str | int] = {"iface": dev, "state": state, "mac": "", "ip": "", "active_ssid": conn, "signal": 0}
            det = get_device_info(dev)
            info["mac"] = det.get("mac", "")
            info["ip"] = det.get("ip", "")
            result.append(info)
    return result


def get_device_info(iface: str) -> dict:
    """Returns {mac, ip, gateway, dns, speed} for a device by interface name."""
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return {}
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            if _g(_DEV_IFACE, 'Interface', dev_obj) != iface:
                continue
            info: dict[str, str] = {"mac": "", "ip": "", "gateway": "", "dns": "", "speed": ""}
            info["mac"] = str(_g(_DEV_IFACE, 'HwAddress', dev_obj) or "")
            state = int(_g(_DEV_IFACE, 'State', dev_obj))
            if state >= _NM_DEVICE_STATE_ACTIVATED:
                ip4_path = _g(_DEV_IFACE, 'Ip4Config', dev_obj)
                if ip4_path and ip4_path != '/':
                    ip4_obj = _bus.get_object('org.freedesktop.NetworkManager', ip4_path)
                    addrs = _g(_IP4_IFACE, 'Addresses', ip4_obj)
                    if addrs:
                        info["ip"] = _ip4_str(addrs[0][0])
                        info["gateway"] = _ip4_str(addrs[0][2])
                    gw = _g(_IP4_IFACE, 'Gateway', ip4_obj)
                    if gw:
                        info["gateway"] = str(gw)
                    ns = _g(_IP4_IFACE, 'Nameservers', ip4_obj)
                    if ns:
                        info["dns"] = ", ".join(_ip4_str(n) for n in ns)
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


def get_wifi_ap_info(ssid: str) -> dict | None:
    """Returns {channel, frequency, rate, signal, security, bssid} for a given SSID."""
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return None
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            dtype = _g(_DEV_IFACE, 'DeviceType', dev_obj)
            if int(dtype) != _NM_DEVICE_TYPE_WIFI:
                continue
            ap_paths = _c('GetAllAccessPoints', _WIFI_DEV_IFACE, dev_obj)
            if not ap_paths:
                continue
            for ap_path in ap_paths:
                ap_obj = _bus.get_object('org.freedesktop.NetworkManager', ap_path)
                name = _ssid(_p(ap_obj).Get(_AP_IFACE, 'Ssid'))
                if name != ssid:
                    continue
                freq = int(_p(ap_obj).Get(_AP_IFACE, 'Frequency'))
                return {
                    "channel": _freq_to_channel(freq),
                    "frequency": str(freq),
                    "rate": str(_p(ap_obj).Get(_AP_IFACE, 'MaxBitrate')),
                    "signal": int(_p(ap_obj).Get(_AP_IFACE, 'Strength')),
                    "security": _ap_security(
                        int(_p(ap_obj).Get(_AP_IFACE, 'Flags')),
                        int(_p(ap_obj).Get(_AP_IFACE, 'WpaFlags')),
                        int(_p(ap_obj).Get(_AP_IFACE, 'RsnFlags')),
                    ),
                    "bssid": str(_p(ap_obj).Get(_AP_IFACE, 'HwAddress') or ""),
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
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return None
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            dtype = _g(_DEV_IFACE, 'DeviceType', dev_obj)
            if int(dtype) != _NM_DEVICE_TYPE_WIFI:
                continue
            try:
                mode = int(_g(_WIFI_DEV_IFACE, 'Mode', dev_obj))
            except Exception:
                mode = -1
            if mode != _NM_80211_MODE_AP:
                continue
            ac_path = _g(_DEV_IFACE, 'ActiveConnection', dev_obj)
            if ac_path and ac_path != '/':
                ac_obj = _bus.get_object('org.freedesktop.NetworkManager', ac_path)
                return str(_p(ac_obj).Get(_AC_IFACE, 'Id') or "")
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
    if _HAS_DBUS:
        paths = _g(_NM_IFACE, 'AllDevices')
        if not paths:
            return {}
        for dp in paths:
            dev_obj = _bus.get_object('org.freedesktop.NetworkManager', dp)
            dtype = int(_g(_DEV_IFACE, 'DeviceType', dev_obj))
            if dtype != _NM_DEVICE_TYPE_ETHERNET:
                continue
            dev = str(_g(_DEV_IFACE, 'Interface', dev_obj) or "")
            state = int(_g(_DEV_IFACE, 'State', dev_obj))
            ac_path = _g(_DEV_IFACE, 'ActiveConnection', dev_obj)
            conn = ""
            if ac_path and ac_path != '/':
                ac_obj = _bus.get_object('org.freedesktop.NetworkManager', ac_path)
                conn = str(_p(ac_obj).Get(_AC_IFACE, 'Id') or "")
            info = {
                "device": dev,
                "state": _state_str(state),
                "connection": conn,
                "ip": "",
            }
            if state >= _NM_DEVICE_STATE_ACTIVATED:
                ip4_path = _g(_DEV_IFACE, 'Ip4Config', dev_obj)
                if ip4_path and ip4_path != '/':
                    ip4_obj = _bus.get_object('org.freedesktop.NetworkManager', ip4_path)
                    addrs = _g(_IP4_IFACE, 'Addresses', ip4_obj)
                    if addrs:
                        info["ip"] = _ip4_str(addrs[0][0])
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
