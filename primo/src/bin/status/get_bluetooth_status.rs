use primo::{print_json, run_cmd};
use serde::Serialize;
use std::collections::HashMap;

#[derive(Serialize)]
struct BluetoothDevice {
    name: String,
    address: String,
    connected: bool,
    paired: bool,
    battery: Option<f64>,
}

#[derive(Serialize)]
struct BluetoothStatus {
    enabled: bool,
    devices: Vec<BluetoothDevice>,
}

fn is_bluetooth_enabled() -> bool {
    let out = run_cmd("bluetoothctl", &["show"]).unwrap_or_default();
    out.lines()
        .any(|line| line.contains("Powered:") && line.contains("yes"))
}

fn parse_upower_batteries() -> HashMap<String, f64> {
    let out = run_cmd("upower", &["-d"]).unwrap_or_default();
    let mut batteries = HashMap::new();
    let mut current_addr = String::new();

    for line in out.lines() {
        let t = line.trim();
        if let Some(s) = t.strip_prefix("serial:") {
            current_addr = s.trim().to_uppercase();
        } else if t.starts_with("percentage:") && !current_addr.is_empty() {
            if let Ok(pct) = t
                .trim_start_matches("percentage:")
                .trim()
                .trim_end_matches('%')
                .parse::<f64>()
            {
                batteries.insert(current_addr.clone(), pct);
            }
        }
    }
    batteries
}

fn get_battery_for_device(addr: &str, upower: &HashMap<String, f64>) -> Option<f64> {
    let upper = addr.to_uppercase();
    if let Some(pct) = upower.get(&upper) {
        return Some(*pct);
    }
    for (key, pct) in upower {
        if key.contains(&upper) {
            return Some(*pct);
        }
    }
    let bat_out = run_cmd("bluetoothctl", &["battery-info", addr]).unwrap_or_default();
    for line in bat_out.lines() {
        let t = line.trim();
        if t.starts_with("Battery Percentage:") {
            if let Some(start) = t.rfind('(') {
                if let Some(end) = t.rfind(')') {
                    if let Ok(pct) = t[start + 1..end].trim_end_matches('%').parse::<f64>() {
                        return Some(pct);
                    }
                }
            }
        }
    }
    None
}

fn main() {
    let enabled = is_bluetooth_enabled();
    let upower = parse_upower_batteries();
    let mut devices = Vec::new();

    if enabled {
        if let Some(out) = run_cmd("bluetoothctl", &["devices"]) {
            for line in out.lines() {
                if let Some(rest) = line.strip_prefix("Device ") {
                    if let Some(space) = rest.find(' ') {
                        let addr = rest[..space].to_string();
                        let name = rest[space + 1..].to_string();

                        let info = run_cmd("bluetoothctl", &["info", &addr]).unwrap_or_default();
                        let mut connected = false;
                        let mut paired = false;
                        for l in info.lines() {
                            let t = l.trim();
                            if t.starts_with("Connected:") {
                                connected = t.contains("yes");
                            }
                            if t.starts_with("Paired:") {
                                paired = t.contains("yes");
                            }
                        }

                        let battery = get_battery_for_device(&addr, &upower);

                        devices.push(BluetoothDevice {
                            name,
                            address: addr,
                            connected,
                            paired,
                            battery,
                        });
                    }
                }
            }
        }
    }

    devices.sort_by(|a, b| {
        if a.connected != b.connected {
            b.connected.cmp(&a.connected)
        } else {
            a.name.cmp(&b.name)
        }
    });

    let status = BluetoothStatus { enabled, devices };
    print_json(&status);
}
