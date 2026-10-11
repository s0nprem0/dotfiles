use serde::Serialize;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::thread::sleep;
use std::time::Duration;

use primo::print_json;

#[derive(Serialize)]
struct SysmonStatus {
    cpu_usage: i32,
    cpu_temp: i32,
    memory_total_gb: f64,
    memory_used_gb: f64,
    memory_percent: i32,
    disk_total_gb: f64,
    disk_used_gb: f64,
    disk_percent: i32,
    net_rx_bytes_sec: f64,
    net_tx_bytes_sec: f64,
}

fn read_cpu_times() -> Option<(u64, u64)> {
    let file = File::open("/proc/stat").ok()?;
    let reader = BufReader::new(file);
    for line in reader.lines() {
        let line = line.ok()?;
        if line.starts_with("cpu ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 5 {
                let user: u64 = parts[1].parse().unwrap_or(0);
                let nice: u64 = parts[2].parse().unwrap_or(0);
                let system: u64 = parts[3].parse().unwrap_or(0);
                let idle: u64 = parts[4].parse().unwrap_or(0);
                let total = user + nice + system + idle;
                return Some((total, idle));
            }
        }
    }
    None
}

fn get_cpu_usage() -> i32 {
    if let Some((total1, idle1)) = read_cpu_times() {
        sleep(Duration::from_millis(100));
        if let Some((total2, idle2)) = read_cpu_times() {
            let total_diff = total2.saturating_sub(total1);
            let idle_diff = idle2.saturating_sub(idle1);
            if total_diff > 0 {
                return ((total_diff - idle_diff) as f64 / total_diff as f64 * 100.0).round() as i32;
            }
        }
    }
    0
}

fn get_cpu_temp() -> i32 {
    if let Ok(temp_str) = std::fs::read_to_string("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(temp_raw) = temp_str.trim().parse::<i32>() {
            return temp_raw / 1000;
        }
    }
    0
}

fn get_memory() -> (f64, f64, i32) {
    let mut total_kb = 0.0;
    let mut available_kb = 0.0;
    if let Ok(file) = File::open("/proc/meminfo") {
        let reader = BufReader::new(file);
        for line in reader.lines().map_while(Result::ok) {
            if line.starts_with("MemTotal:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    total_kb = parts[1].parse().unwrap_or(0.0);
                }
            } else if line.starts_with("MemAvailable:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    available_kb = parts[1].parse().unwrap_or(0.0);
                }
            }
        }
    }
    let total_gb = total_kb / 1024.0 / 1024.0;
    let used_gb = (total_kb - available_kb) / 1024.0 / 1024.0;
    let percent = if total_kb > 0.0 {
        (((total_kb - available_kb) / total_kb * 100.0) as f64).round() as i32
    } else {
        0
    };
    (total_gb, used_gb, percent)
}

fn get_disk() -> (f64, f64, i32) {
    let out = std::process::Command::new("df")
        .args(["-B1", "/"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    for line in out.lines().skip(1) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 4 {
            let total: f64 = parts[1].parse().unwrap_or(0.0);
            let used: f64 = parts[2].parse().unwrap_or(0.0);
            let total_gb = total / 1024.0 / 1024.0 / 1024.0;
            let used_gb = used / 1024.0 / 1024.0 / 1024.0;
            let percent = if total > 0.0 {
                (used / total * 100.0).round() as i32
            } else {
                0
            };
            return (total_gb, used_gb, percent);
        }
    }
    (0.0, 0.0, 0)
}

struct NetSample {
    rx_bytes: u64,
    tx_bytes: u64,
}

fn read_net_bytes() -> NetSample {
    let mut rx = 0u64;
    let mut tx = 0u64;
    if let Ok(file) = File::open("/proc/net/dev") {
        let reader = BufReader::new(file);
        for line in reader.lines().map_while(Result::ok).skip(2) {
            if let Some(pos) = line.find(':') {
                let rest = &line[pos + 1..];
                let parts: Vec<&str> = rest.split_whitespace().collect();
                if parts.len() >= 10 {
                    if let Ok(r) = parts[0].parse::<u64>() {
                        rx += r;
                    }
                    if let Ok(t) = parts[8].parse::<u64>() {
                        tx += t;
                    }
                }
            }
        }
    }
    NetSample { rx_bytes: rx, tx_bytes: tx }
}

fn get_network() -> (f64, f64) {
    let s1 = read_net_bytes();
    sleep(Duration::from_secs(1));
    let s2 = read_net_bytes();

    let rx = s2.rx_bytes.saturating_sub(s1.rx_bytes) as f64;
    let tx = s2.tx_bytes.saturating_sub(s1.tx_bytes) as f64;
    (rx, tx)
}

fn main() {
    let cpu_usage = get_cpu_usage();
    let cpu_temp = get_cpu_temp();
    let (mem_total, mem_used, mem_pct) = get_memory();
    let (disk_total, disk_used, disk_pct) = get_disk();
    let (net_rx, net_tx) = get_network();

    print_json(&SysmonStatus {
        cpu_usage,
        cpu_temp,
        memory_total_gb: (mem_total * 10.0).round() / 10.0,
        memory_used_gb: (mem_used * 10.0).round() / 10.0,
        memory_percent: mem_pct,
        disk_total_gb: (disk_total * 10.0).round() / 10.0,
        disk_used_gb: (disk_used * 10.0).round() / 10.0,
        disk_percent: disk_pct,
        net_rx_bytes_sec: net_rx,
        net_tx_bytes_sec: net_tx,
    });
}
