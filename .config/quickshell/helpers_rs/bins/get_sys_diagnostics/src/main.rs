use helpers_rs::read_trimmed;
use serde::Serialize;
use std::path::Path;

#[derive(Serialize)]
struct CpuInfo {
    temp: f64,
    label: String,
}

#[derive(Serialize)]
struct MemInfo {
    used_gb: f64,
    total_gb: f64,
    percent: i64,
}

#[derive(Serialize)]
struct DiskInfo {
    used: String,
    total: String,
    percent: i64,
}

#[derive(Serialize)]
struct SysDiagnostics {
    cpu: Option<CpuInfo>,
    memory: Option<MemInfo>,
    disk: Option<DiskInfo>,
}

fn read_cpu_temp() -> Option<CpuInfo> {
    let path = Path::new("/sys/class/thermal/thermal_zone0/temp");
    let raw = read_trimmed(path)?;
    let millicelsius: f64 = raw.parse().ok()?;
    let celsius = millicelsius / 1000.0;
    let label = format!("{:.1}°C", celsius);
    Some(CpuInfo {
        temp: celsius,
        label,
    })
}

fn read_memory() -> Option<MemInfo> {
    let content = std::fs::read_to_string("/proc/meminfo").ok()?;
    let mut mem_total_kb: f64 = 0.0;
    let mut mem_available_kb: f64 = 0.0;

    for line in content.lines() {
        if let Some(val) = line.strip_prefix("MemTotal:") {
            mem_total_kb = val.trim().split_whitespace().next()?.parse().ok()?;
        } else if let Some(val) = line.strip_prefix("MemAvailable:") {
            mem_available_kb = val.trim().split_whitespace().next()?.parse().ok()?;
        }
    }

    if mem_total_kb == 0.0 {
        return None;
    }

    let used_kb: f64 = mem_total_kb - mem_available_kb;
    let total_gb: f64 = mem_total_kb / (1024.0 * 1024.0);
    let used_gb: f64 = used_kb / (1024.0 * 1024.0);
    let percent: i64 = ((used_kb / mem_total_kb) * 100.0).round() as i64;

    Some(MemInfo {
        used_gb: (used_gb * 10.0).round() / 10.0,
        total_gb: (total_gb * 10.0).round() / 10.0,
        percent,
    })
}

fn read_disk() -> Option<DiskInfo> {
    let output = std::process::Command::new("df")
        .args(["-h", "/"])
        .output()
        .ok()?;
    let output_str = String::from_utf8_lossy(&output.stdout);
    let line = output_str.lines().nth(1)?;
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.len() < 5 {
        return None;
    }
    let total = parts[1].to_string();
    let used = parts[2].to_string();
    let pct_str = parts[4].trim_end_matches('%');
    let percent: i64 = pct_str.parse().unwrap_or(0);

    Some(DiskInfo {
        used,
        total,
        percent,
    })
}

fn main() {
    let diagnostics = SysDiagnostics {
        cpu: read_cpu_temp(),
        memory: read_memory(),
        disk: read_disk(),
    };

    helpers_rs::print_json(&diagnostics);
}
