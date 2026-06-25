use helpers_rs::print_json;
use serde::Serialize;
use std::fs;
use std::path::PathBuf;

#[derive(Serialize)]
struct PresetEntry {
    file: String,
    name: String,
    variant: String,
    primary: String,
}

#[derive(Serialize)]
struct PresetList {
    presets: Vec<PresetEntry>,
}

fn preset_dir() -> PathBuf {
    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    home.join(".config/matugen/presets")
}

#[derive(Default, serde::Deserialize)]
struct PresetShell {
    #[serde(default)]
    primary: String,
}

#[derive(Default, serde::Deserialize)]
struct PresetMeta {
    #[serde(default)]
    name: String,
    #[serde(default)]
    variant: String,
    #[serde(default)]
    shell: PresetShell,
}

fn main() {
    let dir = preset_dir();
    let dir = if let Ok(d) = fs::read_dir(&dir) {
        d
    } else {
        print_json(&PresetList { presets: vec![] });
        return;
    };

    let mut presets: Vec<PresetEntry> = Vec::new();
    for entry in dir.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            _ => continue,
        };
        let meta: PresetMeta = match serde_json::from_str(&content) {
            Ok(m) => m,
            _ => continue,
        };
        let file_str = path.to_string_lossy().to_string();
        presets.push(PresetEntry {
            file: file_str,
            name: meta.name,
            variant: meta.variant,
            primary: meta.shell.primary,
        });
    }

    print_json(&PresetList { presets });
}
