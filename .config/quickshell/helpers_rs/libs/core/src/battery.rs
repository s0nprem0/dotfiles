use std::fs;
use std::path::{Path, PathBuf};

use crate::state_file::read_trimmed;

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

            if energy_full > 0.0 {
                total_full += energy_full;
                total_now += energy_now;
                total_power += power_now;
            } else {
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
        rate: total_power,
        ..BatterySnapshot::default()
    }
}
