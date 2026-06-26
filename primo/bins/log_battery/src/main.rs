use primo::battery_snapshot;
use std::env;
use std::fs;
use std::path::PathBuf;

fn history_path() -> PathBuf {
    let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    home.join(".cache/quickshell/battery_history.json")
}

fn main() {
    let battery = battery_snapshot();
    let path = history_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let mut history: Vec<f64> = fs::read_to_string(&path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();

    history.push(battery.power_w);
    if history.len() > 24 {
        history = history[history.len() - 24..].to_vec();
    }

    if let Ok(json) = serde_json::to_string(&history) {
        let _ = fs::write(&path, &json);
    }
}
