use helpers_rs::{cache_dir, print_json, read_trimmed};
use serde::Serialize;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[derive(Serialize)]
struct CaffeineStatus {
    active: bool,
}

fn state_file() -> PathBuf {
    let mut p = cache_dir();
    p.push("caffeine_state");
    p
}

fn is_active() -> bool {
    read_trimmed(&state_file()).is_some()
}

fn caffeine_on() {
    fs::write(state_file(), "active\n").ok();
    Command::new("systemd-inhibit")
        .args([
            "--what=sleep:idle:handle-lid-switch",
            "--who=quickshell-caffeine",
            "--why=Manual caffeine toggle",
            "sleep",
            "infinity",
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .ok();
    print_json(&CaffeineStatus { active: true });
}

fn caffeine_off() {
    let _ = fs::remove_file(state_file());
    Command::new("pkill")
        .args(["-f", "systemd-inhibit.*quickshell-caffeine"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .ok();
    print_json(&CaffeineStatus { active: false });
}

fn main() {
    let action = std::env::args().nth(1).unwrap_or_default();
    match action.as_str() {
        "toggle" => {
            if is_active() {
                caffeine_off();
            } else {
                caffeine_on();
            }
        }
        "on" => caffeine_on(),
        "off" => caffeine_off(),
        "status" => {
            print_json(&CaffeineStatus {
                active: is_active(),
            });
        }
        _ => {
            eprintln!(r#"{{"error":"Usage: caffeine <toggle|status|on|off>"}}"#);
            std::process::exit(1);
        }
    }
}
