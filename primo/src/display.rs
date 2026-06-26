use serde::Deserialize;
use std::collections::HashMap;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum DisplayMode {
    Extend,
    Duplicate,
    External,
    Internal,
}

impl Default for DisplayMode {
    fn default() -> Self {
        DisplayMode::Extend
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct MonitorSettings {
    pub scale: Option<f64>,
    pub transform: Option<u32>,
}

#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
pub struct DisplayConfig {
    pub per_monitor: HashMap<String, MonitorSettings>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct DisplayProfile {
    pub name: String,
    pub description: String,
    pub mode: DisplayMode,
    pub monitors: HashMap<String, MonitorSettings>,
}

impl Default for DisplayProfile {
    fn default() -> Self {
        DisplayProfile {
            name: "default".to_string(),
            description: "Default configuration".to_string(),
            mode: DisplayMode::Extend,
            monitors: HashMap::new(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Monitor {
    pub name: String,
    pub id: u32,
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
    pub scale: f64,
    pub transform: u32,
    pub transform_label: String,
    pub refresh_rate: Option<f64>,
    pub disabled: bool,
    pub mirror: Option<String>,
    pub is_internal: bool,
    pub workspace_id: Option<u32>,
    pub focused: bool,
    pub active: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct MonitorRaw {
    id: u32,
    name: String,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    scale: f64,
    transform: u32,
    refreshRate: Option<f64>,
    disabled: bool,
    #[serde(rename = "mirrorOf")]
    mirror_of: String,
    #[serde(rename = "activeWorkspaceId")]
    active_workspace_id: Option<u32>,
    focused: bool,
    active: bool,
}

fn is_internal_name(name: &str) -> bool {
    name.starts_with("eDP")
        || name.starts_with("DSI")
        || name.starts_with("LVDS")
        || name.starts_with("OLED")
}

fn transform_label(transform: u32) -> String {
    match transform {
        0 => "normal".to_string(),
        1 => "90°".to_string(),
        2 => "180°".to_string(),
        3 => "270°".to_string(),
        _ => format!("unknown({})", transform),
    }
}

fn raw_to_monitor(raw: MonitorRaw) -> Monitor {
    let is_internal = is_internal_name(&raw.name);
    let mirror = match raw.mirror_of.as_str() {
        "none" | "" => None,
        other => Some(other.to_string()),
    };
    Monitor {
        name: raw.name,
        id: raw.id,
        x: raw.x,
        y: raw.y,
        width: raw.width,
        height: raw.height,
        scale: raw.scale,
        transform: raw.transform,
        transform_label: transform_label(raw.transform),
        refresh_rate: raw.refreshRate,
        disabled: raw.disabled,
        mirror,
        is_internal,
        workspace_id: raw.active_workspace_id,
        focused: raw.focused,
        active: raw.active,
    }
}

pub fn get_current_mode() -> DisplayMode {
    let monitors = get_monitors();
    get_current_mode_from(&monitors)
}

pub fn get_current_mode_from(monitors: &[Monitor]) -> DisplayMode {
    let internal_on = monitors.iter().any(|m| m.is_internal && !m.disabled);
    let external_on = monitors.iter().any(|m| !m.is_internal && !m.disabled);

    if !internal_on && external_on {
        DisplayMode::External
    } else if internal_on && external_on {
        let internal_names: Vec<&str> = monitors
            .iter()
            .filter(|m| m.is_internal)
            .map(|m| m.name.as_str())
            .collect();
        let in_duplicate = monitors.iter().any(|m| {
            !m.is_internal
                && !m.disabled
                && m.mirror
                    .as_deref()
                    .is_some_and(|mirrored| internal_names.contains(&mirrored))
        });
        if in_duplicate {
            DisplayMode::Duplicate
        } else {
            DisplayMode::Extend
        }
    } else if internal_on && !external_on {
        DisplayMode::Internal
    } else {
        DisplayMode::Extend
    }
}

fn find_internal(monitors: &[Monitor]) -> Option<&Monitor> {
    monitors.iter().find(|m| m.is_internal && !m.disabled)
}

fn find_external(monitors: &[Monitor]) -> Option<&Monitor> {
    monitors.iter().find(|m| !m.is_internal && !m.disabled)
}

pub fn toggle_mode() {
    let monitors = get_monitors();
    let has_external = find_external(&monitors).is_some();
    let current = get_current_mode();

    let next = match current {
        DisplayMode::Extend if has_external => DisplayMode::Duplicate,
        DisplayMode::Extend => DisplayMode::Internal,
        DisplayMode::Duplicate => DisplayMode::External,
        DisplayMode::External => DisplayMode::Internal,
        DisplayMode::Internal => DisplayMode::Extend,
    };

    set_mode(next, &monitors);
}

pub fn set_mode(mode: DisplayMode, monitors: &[Monitor]) {
    let internal_name = find_internal(monitors).map(|m| m.name.as_str());
    let external_name = find_external(monitors).map(|m| m.name.as_str());
    let has_external = external_name.is_some();

    match mode {
        DisplayMode::Extend => {
            if let Some(name) = internal_name {
                run_keyword(name, "mode preferred position auto scale 1");
            }
            if let Some(name) = external_name {
                run_keyword(name, "mode preferred position auto-right scale 1");
            }
        }
        DisplayMode::Duplicate if !has_external => {
            notify("No external display");
            return;
        }
        DisplayMode::Duplicate => {
            let int_name = internal_name.unwrap_or_default();
            let ext_name = external_name.unwrap_or_default();
            let preferred = get_preferred_mode(monitors, int_name);
            run_keyword(int_name, &format!("mode {} position 0x0 scale 1", preferred));
            run_keyword(
                ext_name,
                &format!("mode {} position 0x0 scale 1 mirror {}", preferred, int_name),
            );
        }
        DisplayMode::External if !has_external => {
            notify("No external display");
            return;
        }
        DisplayMode::External => {
            if let Some(name) = internal_name {
                run_keyword(name, "disabled true");
            }
            if let Some(name) = external_name {
                run_keyword(name, "mode preferred position 0x0 scale 1");
            }
        }
        DisplayMode::Internal => {
            if let Some(name) = internal_name {
                run_keyword(name, "mode preferred position auto scale 1");
            }
            if let Some(name) = external_name {
                run_keyword(name, "disabled true");
            }
        }
    }

    notify(&format!("Display: {:?}", mode));
}

pub fn set_mode_verified(mode: DisplayMode, monitors: &[Monitor]) -> Result<(), String> {
    set_mode(mode, monitors);
    
    thread::sleep(Duration::from_millis(100));
    
    let new_mode = get_current_mode_from(monitors);
    
    if new_mode == mode {
        Ok(())
    } else {
        Err(format!("Mode verification failed: expected {:?}, got {:?}", mode, new_mode))
    }
}

fn run_keyword(output: &str, args: &str) {
    let _ = Command::new("hyprctl")
        .args(["keyword", &format!("monitor.{}.{}", output, args)])
        .status();
}

fn get_preferred_mode(monitors: &[Monitor], name: &str) -> String {
    monitors
        .iter()
        .find(|m| m.name == name)
        .and_then(|m| {
            if m.width > 0 {
                let rate = m.refresh_rate.unwrap_or(60.0);
                Some(format!("{}x{}@{:.2}", m.width, m.height, rate))
            } else {
                Some("preferred".to_string())
            }
        })
        .unwrap_or_else(|| "preferred".to_string())
}

fn notify(message: &str) {
    let _ = Command::new("notify-send")
        .args(["-t", "1000", "Display", message])
        .status();
}

pub fn get_monitors() -> Vec<Monitor> {
    let output = match Command::new("hyprctl").args(["monitors", "-j"]).output() {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(e) => {
            eprintln!("display: failed to run hyprctl: {e}");
            return Vec::new();
        }
    };

    let raws: Vec<MonitorRaw> = match serde_json::from_str(&output) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("display: failed to parse hyprctl JSON: {e}");
            return Vec::new();
        }
    };

    raws.into_iter().map(raw_to_monitor).collect()
}

pub fn get_primary_monitor(monitors: &[Monitor]) -> Option<&Monitor> {
    monitors.iter().find(|m| m.focused && !m.disabled)
}

pub fn get_monitor_by_id(monitors: &[Monitor], id: u32) -> Option<&Monitor> {
    monitors.iter().find(|m| m.id == id)
}

pub fn get_monitor_by_name<'a>(monitors: &'a [Monitor], name: &str) -> Option<&'a Monitor> {
    monitors.iter().find(|m| m.name == name)
}

pub fn get_internal_monitors(monitors: &[Monitor]) -> Vec<&Monitor> {
    monitors.iter().filter(|m| m.is_internal && !m.disabled).collect()
}

pub fn get_external_monitors(monitors: &[Monitor]) -> Vec<&Monitor> {
    monitors.iter().filter(|m| !m.is_internal && !m.disabled).collect()
}

use std::sync::{Arc, Mutex};

lazy_static::lazy_static! {
    static ref MONITOR_CACHE: Arc<Mutex<(Vec<Monitor>, Instant)>> = Arc::new(Mutex::new((Vec::new(), Instant::now())));
    static ref CACHE_TTL: Duration = Duration::from_millis(100);
}

pub fn get_monitors_cached() -> Vec<Monitor> {
    let cache = MONITOR_CACHE.lock().unwrap();
    if cache.1.elapsed() < *CACHE_TTL {
        return cache.0.clone();
    }
    drop(cache);
    let fresh = get_monitors();
    *MONITOR_CACHE.lock().unwrap() = (fresh.clone(), Instant::now());
    fresh
}

use std::fs;
use std::path::PathBuf;

pub fn get_config_path() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("quickshell")
        .join("display_config.json")
}

pub fn load_display_config() -> DisplayConfig {
    let path = get_config_path();
    if path.exists() {
        match fs::read_to_string(&path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => DisplayConfig::default(),
        }
    } else {
        DisplayConfig::default()
    }
}

pub fn save_display_config(config: &DisplayConfig) -> std::io::Result<()> {
    let path = get_config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let content = serde_json::to_string_pretty(config).unwrap_or_default();
    fs::write(path, content)
}

pub fn get_monitor_scale(_monitors: &[Monitor], name: &str) -> f64 {
    let config = load_display_config();
    config.per_monitor.get(name).and_then(|s| s.scale).unwrap_or(1.0)
}

pub fn set_monitor_scale(_monitors: &[Monitor], name: &str, scale: f64) -> std::io::Result<()> {
    let mut config = load_display_config();
    let entry = config.per_monitor.entry(name.to_string()).or_insert(MonitorSettings {
        scale: None,
        transform: None,
    });
    entry.scale = Some(scale);
    save_display_config(&config)
}

pub fn get_monitor_transform(_monitors: &[Monitor], name: &str) -> Option<u32> {
    let config = load_display_config();
    config.per_monitor.get(name).and_then(|s| s.transform)
}

pub fn set_monitor_transform(_monitors: &[Monitor], name: &str, transform: u32) -> std::io::Result<()> {
    let mut config = load_display_config();
    let entry = config.per_monitor.entry(name.to_string()).or_insert(MonitorSettings {
        scale: None,
        transform: None,
    });
    entry.transform = Some(transform);
    save_display_config(&config)
}

pub fn get_profiles_path() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("quickshell")
        .join("display_profiles.json")
}

pub fn load_profiles() -> HashMap<String, DisplayProfile> {
    let path = get_profiles_path();
    if path.exists() {
        match fs::read_to_string(&path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => HashMap::new(),
        }
    } else {
        HashMap::new()
    }
}

pub fn save_profiles(profiles: &HashMap<String, DisplayProfile>) -> std::io::Result<()> {
    let path = get_profiles_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let content = serde_json::to_string_pretty(profiles).unwrap_or_default();
    fs::write(path, content)
}

pub fn get_profile<'a>(name: &str, profiles: &'a HashMap<String, DisplayProfile>) -> Option<&'a DisplayProfile> {
    profiles.get(name)
}

pub fn apply_profile(profile: &DisplayProfile, monitors: &[Monitor]) {
    set_mode(profile.mode, monitors);
}
