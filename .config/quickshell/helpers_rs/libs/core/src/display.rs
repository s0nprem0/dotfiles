use std::process::Command;

const INTERNAL: &str = "eDP-1";
const EXTERNAL: &str = "HDMI-A-1";

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

pub fn get_current_mode() -> DisplayMode {
    let monitors = get_monitors();
    let internal_on = monitors.iter().any(|m| m.name == INTERNAL && !m.disabled);
    let external_on = monitors.iter().any(|m| m.name == EXTERNAL && !m.disabled);

    if !internal_on && external_on {
        DisplayMode::External
    } else if internal_on && external_on {
        if monitors.iter().any(|m| m.name == EXTERNAL && m.mirror.as_deref() == Some(INTERNAL)) {
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

pub fn toggle_mode() {
    let monitors = get_monitors();
    let has_external = monitors.iter().any(|m| m.name == EXTERNAL && !m.disabled);
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
    let has_external = monitors.iter().any(|m| m.name == EXTERNAL && !m.disabled);

    match mode {
        DisplayMode::Extend => {
            run_keyword(INTERNAL, "mode preferred position auto scale 1");
            if has_external {
                run_keyword(EXTERNAL, "mode preferred position auto-right scale 1");
            }
        }
        DisplayMode::Duplicate if !has_external => {
            notify("No external display");
            return;
        }
        DisplayMode::Duplicate => {
            let internal_mode = get_preferred_mode(monitors, INTERNAL);
            run_keyword(INTERNAL, &format!("mode {} position 0x0 scale 1", internal_mode));
            run_keyword(EXTERNAL, &format!("mode {} position 0x0 scale 1 mirror {}", internal_mode, INTERNAL));
        }
        DisplayMode::External if !has_external => {
            notify("No external display");
            return;
        }
        DisplayMode::External => {
            run_keyword(INTERNAL, "disabled true");
            run_keyword(EXTERNAL, "mode preferred position 0x0 scale 1");
        }
        DisplayMode::Internal => {
            run_keyword(INTERNAL, "mode preferred position auto scale 1");
            run_keyword(EXTERNAL, "disabled true");
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
    monitors.iter()
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

#[derive(Debug)]
pub struct Monitor {
    pub name: String,
    pub disabled: bool,
    pub width: u32,
    pub height: u32,
    pub refresh_rate: Option<f64>,
    pub mirror: Option<String>,
}

pub fn get_monitors() -> Vec<Monitor> {
    let output = match Command::new("hyprctl").args(["monitors", "-j"]).output() {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return Vec::new(),
    };

    let mut monitors = Vec::new();

    for line in output.lines() {
        if line.contains("\"name\"") {
            let name = extract_string(line, "name").unwrap_or_default();
            let disabled: bool = line.split("\"disabled\"")
                .nth(1)
                .and_then(|s| s.split(':').nth(1))
                .and_then(|s| s.trim().trim_end_matches(',').parse().ok())
                .unwrap_or(false);
            let width: u32 = line.split("\"width\"")
                .nth(1)
                .and_then(|s| s.split(':').nth(1))
                .and_then(|s| s.split(',').next())
                .and_then(|s| s.trim().parse().ok())
                .unwrap_or(0);
            let height: u32 = line.split("\"height\"")
                .nth(1)
                .and_then(|s| s.split(':').nth(1))
                .and_then(|s| s.split(',').next())
                .and_then(|s| s.trim().parse().ok())
                .unwrap_or(0);
            let refresh_rate: Option<f64> = line.split("\"refreshRate\"")
                .nth(1)
                .and_then(|s| s.split(':').nth(1))
                .and_then(|s| s.split(',').next())
                .and_then(|s| s.trim().parse().ok());
            let mirror = extract_string(line, "mirror").into_iter().next();

            monitors.push(Monitor {
                name,
                disabled,
                width,
                height,
                refresh_rate,
                mirror: mirror.filter(|s| !s.is_empty()),
            });
        }
    }

    monitors
}

fn extract_string(line: &str, key: &str) -> Option<String> {
    let start = line.find(&format!("\"{}\"", key))?;
    let rest = &line[start + key.len() + 3..];
    let value_start = rest.find(':')? + 1;
    let value = rest[value_start..].trim_start();
    let end = value.find('"')?;
    Some(value[..end].to_string())
}