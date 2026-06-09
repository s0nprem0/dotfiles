use serde::Serialize;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn run_cmd(cmd: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

pub fn read_trimmed(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

pub fn quickshell_dir() -> PathBuf {
    env::var_os("QUICKSHELL_DIR")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config/quickshell")))
        .unwrap_or_else(|| PathBuf::from(".config/quickshell"))
}

pub fn print_json<T: Serialize>(value: &T) {
    if let Ok(json) = serde_json::to_string(value) {
        println!("{json}");
    }
}

pub fn round_to(value: f64, places: f64) -> f64 {
    (value * places).round() / places
}

#[derive(Clone, Debug, Default)]
pub struct BatterySnapshot {
    pub capacity: i32,
    pub status: String,
    pub full: f64,
    pub full_design: f64,
    pub now: f64,
    pub power_w: f64,
    pub rate: f64,
}

fn parse_num(path: &Path) -> f64 {
    read_trimmed(path)
        .and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(0.0)
}

pub fn find_battery_dir() -> Option<PathBuf> {
    let root = Path::new("/sys/class/power_supply");
    let entries = fs::read_dir(root).ok()?;
    let mut candidates: Vec<PathBuf> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| {
            read_trimmed(&path.join("type"))
                .map(|kind| kind.eq_ignore_ascii_case("battery"))
                .unwrap_or(false)
        })
        .collect();
    candidates.sort();
    candidates.into_iter().next()
}

pub fn battery_snapshot() -> BatterySnapshot {
    let root = Path::new("/sys/class/power_supply");
    let Ok(entries) = fs::read_dir(root) else {
        return BatterySnapshot {
            status: "Unknown".to_string(),
            ..BatterySnapshot::default()
        };
    };

    let mut total_now = 0.0;
    let mut total_full = 0.0;
    let mut total_power = 0.0;
    let mut is_charging = false;
    let mut battery_found = false;

    for entry in entries.flatten() {
        let path = entry.path();
        if read_trimmed(&path.join("type"))
            .unwrap_or_default()
            .eq_ignore_ascii_case("battery")
        {
            battery_found = true;

            let energy_full = parse_num(&path.join("energy_full"));
            let energy_now = parse_num(&path.join("energy_now"));
            let power_now = parse_num(&path.join("power_now"));

            // Standard energy batteries
            if energy_full > 0.0 {
                total_full += energy_full;
                total_now += energy_now;
                total_power += power_now;
            } else {
                // Fallback for batteries reporting charge instead of energy
                total_full += parse_num(&path.join("charge_full"));
                total_now += parse_num(&path.join("charge_now"));
                let voltage = parse_num(&path.join("voltage_now"));
                let current = parse_num(&path.join("current_now"));
                total_power += (voltage * current) / 1e12;
            }

            let status = read_trimmed(&path.join("status")).unwrap_or_default();
            if status.eq_ignore_ascii_case("charging") || status.eq_ignore_ascii_case("full") {
                is_charging = true;
            }
        }
    }

    if !battery_found {
        return BatterySnapshot {
            status: "Unknown".to_string(),
            ..BatterySnapshot::default()
        };
    }

    let final_status = if is_charging {
        "Charging"
    } else {
        "Discharging"
    }
    .to_string();
    let capacity = if total_full > 0.0 {
        ((total_now / total_full) * 100.0).round() as i32
    } else {
        0
    };

    BatterySnapshot {
        capacity,
        status: final_status,
        full: total_full,
        now: total_now,
        power_w: total_power / 1e6,
        ..BatterySnapshot::default()
    }
}

pub fn parse_percent(value: &str) -> Option<i64> {
    let pct = value.split('%').next()?.trim();
    pct.parse::<f64>().ok().map(|v| v.round() as i64)
}

pub fn brightnessctl_percent(device: Option<&str>) -> i32 {
    let out = if let Some(device) = device {
        run_cmd("brightnessctl", &["-d", device, "-m"]).unwrap_or_default()
    } else {
        run_cmd("brightnessctl", &["-m"]).unwrap_or_default()
    };
    let parts: Vec<&str> = out.split(',').collect();
    parts
        .get(3)
        .and_then(|value| parse_percent(value))
        .map(|value| value.clamp(0, 100) as i32)
        .unwrap_or(0)
}

pub fn find_kbd_backlight_device() -> Option<String> {
    let entries = fs::read_dir("/sys/class/leds").ok()?;
    let mut candidates: Vec<String> = entries
        .flatten()
        .filter_map(|entry| entry.file_name().to_str().map(|name| name.to_string()))
        .filter(|name| name.ends_with("kbd_backlight"))
        .collect();
    candidates.sort();
    candidates.into_iter().next()
}

pub fn split_nmcli_t_line(line: &str) -> Vec<String> {
    let mut parts = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                current.push(next);
            }
        } else if c == ':' {
            parts.push(current);
            current = String::new();
        } else {
            current.push(c);
        }
    }
    parts.push(current);
    parts
}

pub fn cidr_to_netmask(prefix: u32) -> Option<String> {
    if prefix > 32 {
        return None;
    }
    let mask = if prefix == 0 {
        0
    } else {
        u32::MAX << (32 - prefix)
    };
    Some(format!(
        "{}.{}.{}.{}",
        (mask >> 24) & 0xFF,
        (mask >> 16) & 0xFF,
        (mask >> 8) & 0xFF,
        mask & 0xFF
    ))
}

pub fn active_wifi_device() -> Option<String> {
    let out = run_cmd("nmcli", &["-t", "-f", "DEVICE,TYPE,STATE", "dev"])?;
    for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 3 && parts[1] == "wifi" && parts[2].contains("connected") {
            return Some(parts[0].clone());
        }
    }
    for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 2 && parts[1] == "wifi" {
            return Some(parts[0].clone());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_escaped_nmcli_fields() {
        let fields = split_nmcli_t_line("yes:My\\:Wifi:AA\\:BB\\:CC:80:540 Mbit/s:WPA2");
        assert_eq!(fields[1], "My:Wifi");
        assert_eq!(fields[2], "AA:BB:CC");
    }

    #[test]
    fn converts_cidr_to_netmask() {
        assert_eq!(cidr_to_netmask(24).as_deref(), Some("255.255.255.0"));
        assert_eq!(cidr_to_netmask(0).as_deref(), Some("0.0.0.0"));
        assert!(cidr_to_netmask(33).is_none());
    }

    #[test]
    fn parses_decimal_percent() {
        assert_eq!(parse_percent("12.5%"), Some(13));
        assert_eq!(parse_percent("100%"), Some(100));
    }
}
