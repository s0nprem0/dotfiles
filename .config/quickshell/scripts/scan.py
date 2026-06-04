#!/usr/bin/env python3
import json, os, sys
sys.path.insert(0, os.path.expanduser("~/.config/rofi/scripts"))
sys.path.insert(0, os.path.expanduser("~/.config/rofi/scripts/network"))
from network import nm_dbus
from network.common import list_wifi_networks, get_active_wifi, is_wifi_enabled

enabled = is_wifi_enabled()
active_ssid = get_active_wifi() if enabled else None
raw = list_wifi_networks() if enabled else {}

networks = []
for ssid, net in raw.items():
    if ssid == "~scanning~":
        continue
    networks.append({
        "ssid": ssid,
        "signal": net.signal if hasattr(net, 'signal') else 0,
        "security": net.security or "",
        "saved": net.saved if hasattr(net, 'saved') else False,
        "active": ssid == active_ssid,
    })

networks.sort(key=lambda n: (
    not n["active"],
    not n["saved"],
    -n["signal"],
    n["ssid"].lower(),
))

print(json.dumps({"enabled": enabled, "activeSsid": active_ssid or "", "networks": networks}))
