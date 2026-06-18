use helpers_rs::{find_kbd_backlight_device, run_cmd};
use serde::Serialize;
use std::fs;
use std::path::PathBuf;

#[derive(Serialize)]
struct State {
    visible: bool,
    text: String,
    kind: String,
    timeout_ms: u64,
}

fn state_file() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".cache/quickshell/osd_state.json")
}

fn write_state(text: &str, kind: &str, timeout_ms: u64) {
    let state = State {
        visible: true,
        text: text.to_string(),
        kind: kind.to_string(),
        timeout_ms,
    };
    persist_state(&state);
}

fn clear_state() {
    let state = State {
        visible: false,
        text: String::new(),
        kind: "info".to_string(),
        timeout_ms: 1200,
    };
    persist_state(&state);
}

fn persist_state(state: &State) {
    let path = state_file();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string(state) {
        let _ = fs::write(&path, json);
    }
}

fn brightness_value() -> String {
    let out = run_cmd("brightnessctl", &["-m"]).unwrap_or_default();
    out.split(',').nth(3).unwrap_or("0%").trim().to_string()
}

fn set_brightness_abs(pct: &str) {
    let _ = run_cmd(
        "brightnessctl",
        &["-e4", "-n2", "set", &format!("{}%", pct)],
    );
    write_state(&format!("brightness {}%", pct), "info", 1200);
}

fn set_brightness(dir: &str) {
    let _ = run_cmd(
        "brightnessctl",
        if dir == "up" {
            &["-e4", "-n2", "set", "5%+"]
        } else {
            &["-e4", "-n2", "set", "5%-"]
        },
    );
    write_state(&format!("brightness {}", brightness_value()), "info", 1200);
}

fn kbd_brightness_value() -> String {
    let dev = match find_kbd_backlight_device() {
        Some(d) => d,
        None => return "0%".to_string(),
    };
    let out = run_cmd("brightnessctl", &["-d", &dev, "-m"]).unwrap_or_default();
    out.split(',').nth(3).unwrap_or("0%").trim().to_string()
}

fn set_kbd_brightness(dir: &str) {
    let dev = match find_kbd_backlight_device() {
        Some(d) => d,
        None => {
            write_state("kbd brightness unavailable", "warn", 1200);
            return;
        }
    };
    match dir {
        "up" | "down" => {
            let _ = run_cmd(
                "brightnessctl",
                &["-d", &dev, "set", if dir == "up" { "1+" } else { "1-" }],
            );
        }
        "cycle" | "cycle-rev" => {
            let max = run_cmd("brightnessctl", &["-d", &dev, "max"])
                .and_then(|s| s.trim().parse::<i32>().ok())
                .unwrap_or(1);
            let cur = run_cmd("brightnessctl", &["-d", &dev, "get"])
                .and_then(|s| s.trim().parse::<i32>().ok())
                .unwrap_or(0);
            let new = if dir == "cycle" {
                if cur >= max { 0 } else { cur + 1 }
            } else {
                if cur <= 0 { max } else { cur - 1 }
            };
            let _ = run_cmd("brightnessctl", &["-d", &dev, "set", &new.to_string()]);
        }
        _ => {}
    }
    write_state(
        &format!("kbd brightness {}", kbd_brightness_value()),
        "info",
        1200,
    );
}

fn sink_volume() -> (i64, bool) {
    let out = run_cmd("wpctl", &["get-volume", "@DEFAULT_AUDIO_SINK@"]).unwrap_or_default();
    let muted = out.to_uppercase().contains("MUTED");
    let val = out
        .split_whitespace()
        .nth(1)
        .and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(0.0);
    ((val * 100.0).round() as i64, muted)
}

fn source_volume() -> (i64, bool) {
    let out = run_cmd("wpctl", &["get-volume", "@DEFAULT_AUDIO_SOURCE@"]).unwrap_or_default();
    let muted = out.to_uppercase().contains("MUTED");
    let val = out
        .split_whitespace()
        .nth(1)
        .and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(0.0);
    ((val * 100.0).round() as i64, muted)
}

fn set_volume(action: &str) {
    match action {
        "up" => {
            let _ = run_cmd(
                "wpctl",
                &["set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"],
            );
            let (pct, _) = sink_volume();
            write_state(&format!("volume {}%", pct), "info", 1200);
        }
        "down" => {
            let _ = run_cmd("wpctl", &["set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]);
            let (pct, _) = sink_volume();
            write_state(&format!("volume {}%", pct), "info", 1200);
        }
        "mute" => {
            let _ = run_cmd("wpctl", &["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            let (_, muted) = sink_volume();
            write_state(
                if muted {
                    "volume muted"
                } else {
                    "volume unmuted"
                },
                if muted { "warn" } else { "info" },
                1200,
            );
        }
        "mic-mute" => {
            let _ = run_cmd("wpctl", &["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
            let (_, muted) = source_volume();
            write_state(
                if muted { "mic muted" } else { "mic unmuted" },
                if muted { "warn" } else { "info" },
                1200,
            );
        }
        _ => {}
    }
}

fn show_text(args: &[String]) {
    if args.is_empty() {
        return;
    }
    let mut parts = args.to_vec();
    let mut timeout = 1200;
    let mut kind = "info".to_string();

    if parts.len() >= 2 {
        if let Ok(t) = parts.last().unwrap().parse::<u64>() {
            timeout = t;
            parts.pop();
        }
    }
    if parts.len() >= 2 {
        let last = parts.last().unwrap();
        if ["info", "good", "warn", "bad"].contains(&last.as_str()) {
            kind = last.clone();
            parts.pop();
        }
    }
    write_state(&parts.join(" "), &kind, timeout);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        return;
    }
    let cmd = &args[1];
    match cmd.as_str() {
        "brightness" if args.len() >= 4 && args[2] == "set" => set_brightness_abs(&args[3]),
        "brightness" if args.len() >= 3 => set_brightness(&args[2]),
        "kbdbrightness" if args.len() >= 3 => set_kbd_brightness(&args[2]),
        "volume" if args.len() >= 3 => set_volume(&args[2]),
        "show" => show_text(&args[2..]),
        "clear" => clear_state(),
        _ => {}
    }
}
