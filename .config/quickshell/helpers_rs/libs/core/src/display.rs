use serde::Deserialize;
use std::process::Command;

#[derive(Debug, Clone, Copy, PartialEq)]
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

#[derive(Debug, Clone)]
pub struct Monitor {
    pub name: String,
    pub disabled: bool,
    pub width: u32,
    pub height: u32,
    pub refresh_rate: Option<f64>,
    pub mirror: Option<String>,
    pub is_internal: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct MonitorRaw {
    name: String,
    disabled: bool,
    width: u32,
    height: u32,
    refresh_rate: Option<f64>,
    #[serde(rename = "mirrorOf")]
    mirror_of: String,
}

fn is_internal_name(name: &str) -> bool {
    name.starts_with("eDP")
        || name.starts_with("DSI")
        || name.starts_with("LVDS")
        || name.starts_with("OLED")
}

fn raw_to_monitor(raw: MonitorRaw) -> Monitor {
    let is_internal = is_internal_name(&raw.name);
    let mirror = match raw.mirror_of.as_str() {
        "none" | "" => None,
        other => Some(other.to_string()),
    };
    Monitor {
        name: raw.name,
        disabled: raw.disabled,
        width: raw.width,
        height: raw.height,
        refresh_rate: raw.refresh_rate,
        mirror,
        is_internal,
    }
}

pub fn get_current_mode() -> DisplayMode {
    let monitors = get_monitors();
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
        Err(_) => return Vec::new(),
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
