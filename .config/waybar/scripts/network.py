#!/usr/bin/env python3
"""Waybar custom module for Wi‑Fi with band indicator, MAC, public IP, etc."""

import json
import os
import sys
import time

sys.path.insert(0, os.path.expanduser("~/.config/rofi/scripts"))
sys.path.insert(0, os.path.expanduser("~/.config/rofi/scripts/network"))

from network import nm_dbus
from network.common import get_power_save, check_connectivity, signal_bars, PUBLIC_IP_CACHE


def _freq_to_band(freq: int) -> str:
    if 2412 <= freq <= 2484:
        return "2.4"
    if 5170 <= freq <= 5825:
        return "5"
    return ""


def get_active_wifi_info():
    if not nm_dbus.wifi_enabled():
        return None
    ssid = nm_dbus.get_active_wifi()
    if not ssid:
        return None
    iface = nm_dbus.get_wifi_iface()
    info = nm_dbus.get_device_info(iface) if iface else {}
    ap = nm_dbus.get_wifi_ap_info(ssid) if ssid else None
    freq = int(ap.get("frequency", 0)) if ap else 0
    signal = ap.get("signal", 0) if ap else 0
    band = _freq_to_band(freq)
    return {
        "ssid": ssid,
        "signal": signal,
        "band": band,
        "freq": freq,
        "ip": info.get("ip", ""),
        "mac": info.get("mac", ""),
        "speed": info.get("speed", ""),
    }


def get_public_ip_text():
    try:
        mtime = os.path.getmtime(PUBLIC_IP_CACHE)
        if time.time() - mtime < 60:
            with open(PUBLIC_IP_CACHE) as f:
                val = f.read().strip()
                if val:
                    return val
    except Exception:
        pass
    return None


def main():
    wifi = get_active_wifi_info()
    state = nm_dbus.wifi_enabled()

    if not state:
        out = {"text": "󰖪  Off", "tooltip": "Wi‑Fi disabled", "class": "disabled"}
        print(json.dumps(out))
        return

    if not wifi:
        out = {"text": "󰤭  Disconnected", "tooltip": "No Wi‑Fi connection\nClick to open network manager",
               "class": "disconnected", "alt": "disconnected"}
        print(json.dumps(out))
        return

    band_tag = f" [{wifi['band']}]" if wifi["band"] else ""
    icon = signal_bars(wifi["signal"])
    text = f"{icon}  {wifi['ssid']}{band_tag}  {wifi['signal']}%"

    pub_ip = get_public_ip_text()
    ps = get_power_save()
    conn = check_connectivity()

    tooltip = f"SSID:  {wifi['ssid']}"
    if wifi["band"]:
        tooltip += f"\nBand:  {wifi['band']} GHz"
    if wifi["freq"]:
        tooltip += f"\nFreq:  {wifi['freq']} MHz"
    tooltip += f"\nSignal:  {wifi['signal']}%"
    if wifi["ip"]:
        tooltip += f"\nIP:  {wifi['ip']}"
    if wifi["speed"]:
        tooltip += f"\nSpeed:  {wifi['speed']} Mb/s"
    if wifi["mac"]:
        tooltip += f"\nMAC:  {wifi['mac']}"
    if ps is not None:
        tooltip += f"\nPower Save:  {'On' if ps else 'Off'}"
    if conn:
        tooltip += f"\nConnectivity:  {conn}"
    if pub_ip:
        tooltip += f"\nPublic IP:  {pub_ip}"

    cls = "connected" if conn == "full" else ("limited" if conn in ("limited", "portal") else "disconnected")

    out = {"text": text, "tooltip": tooltip, "class": cls, "alt": "wifi"}
    print(json.dumps(out))


if __name__ == "__main__":
    main()
