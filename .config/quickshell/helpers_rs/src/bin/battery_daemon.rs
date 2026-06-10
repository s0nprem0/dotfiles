use helpers_rs::{battery_snapshot, find_kbd_backlight_device, run_cmd};
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::{Duration, SystemTime};

#[derive(Clone, Debug, Deserialize)]
struct Settings {
  automation_enabled: Option<bool>,
  low_battery_threshold: Option<i32>,
  ac_profile: Option<String>,
  bat_profile: Option<String>,
  low_profile: Option<String>,
  ac_screen_brightness: Option<i32>,
  bat_screen_brightness: Option<i32>,
  low_screen_brightness: Option<i32>,
  ac_kbd_brightness: Option<i32>,
  bat_kbd_brightness: Option<i32>,
  low_kbd_brightness: Option<i32>,
}

impl Default for Settings {
  fn default() -> Self {
    Self {
      automation_enabled: Some(true),
      low_battery_threshold: Some(25),
      ac_profile: Some("performance".to_string()),
      bat_profile: Some("balanced".to_string()),
      low_profile: Some("power-saver".to_string()),
      ac_screen_brightness: Some(100),
      bat_screen_brightness: Some(70),
      low_screen_brightness: Some(30),
      ac_kbd_brightness: Some(100),
      bat_kbd_brightness: Some(33),
      low_kbd_brightness: Some(0),
    }
  }
}

fn settings_path() -> PathBuf {
  let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
  home.join(".cache/quickshell/battery_settings.json")
}

fn history_path() -> PathBuf {
  let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
  home.join(".cache/quickshell/battery_history.json")
}

fn load_settings() -> Settings {
  let path = settings_path();
  fs::read_to_string(&path)
    .ok()
    .and_then(|s| serde_json::from_str(&s).ok())
    .unwrap_or_default()
}

fn set_profile(profile: &str) {
  let _ = run_cmd("busctl", &[
    "set-property",
    "net.hadess.PowerProfiles",
    "/net/hadess/PowerProfiles",
    "net.hadess.PowerProfiles",
    "ActiveProfile",
    "s",
    profile,
  ]);
}

fn set_brightness(pct: i32, kbd_pct: i32) {
  let _ = run_cmd("brightnessctl", &["set", &format!("{}%", pct)]);
  if let Some(kbd) = find_kbd_backlight_device() {
    let _ = run_cmd("brightnessctl", &["-d", &kbd, "set", &format!("{}%", kbd_pct)]);
  }
}

fn log_history(power_w: f64) {
  let path = history_path();
  if let Some(parent) = path.parent() {
    let _ = fs::create_dir_all(parent);
  }

  let mut history: Vec<f64> = fs::read_to_string(&path)
    .ok()
    .and_then(|s| serde_json::from_str(&s).ok())
    .unwrap_or_default();

  history.push(power_w);
  if history.len() > 24 {
    history = history[history.len() - 24..].to_vec();
  }

  if let Ok(json) = serde_json::to_string(&history) {
    let _ = fs::write(&path, &json);
  }
}

fn send_notification(summary: &str, body: &str) {
  let _ = run_cmd("notify-send", &["--app-name=Battery", summary, body]);
}

enum PowerState {
  Ac,
  Battery,
  LowBattery,
}

fn main() {
  let mut last_state: Option<PowerState> = None;
  let mut last_modified = SystemTime::UNIX_EPOCH;
  let mut settings = Settings::default();
  let mut log_counter: u32 = 0;
  loop {
    if let Ok(meta) = fs::metadata(settings_path()) {
      if let Ok(modified) = meta.modified() {
        if modified != last_modified {
          settings = load_settings();
          last_modified = modified;
        }
      }
    }

    let battery = battery_snapshot();

    // Throttled history logging: every ~60s (20 iterations * 3s)
    log_counter += 1;
    if log_counter >= 20 {
      log_counter = 0;
      if battery.power_w > 0.0 {
        log_history(battery.power_w);
      }
    }

    let current_state = if !settings.automation_enabled.unwrap_or(true) {
      None
    } else if battery.status == "Charging" || battery.status == "Full" {
      Some(PowerState::Ac)
    } else if battery.capacity <= settings.low_battery_threshold.unwrap_or(25) {
      Some(PowerState::LowBattery)
    } else {
      Some(PowerState::Battery)
    };

    if let Some(ref state) = current_state {
      let state_changed = match (&last_state, state) {
        (None, _) => true,
        (Some(PowerState::Ac), PowerState::Battery) => true,
        (Some(PowerState::Ac), PowerState::LowBattery) => true,
        (Some(PowerState::Battery), PowerState::Ac) => true,
        (Some(PowerState::Battery), PowerState::LowBattery) => true,
        (Some(PowerState::LowBattery), PowerState::Ac) => true,
        (Some(PowerState::LowBattery), PowerState::Battery) => true,
        _ => false,
      };

      if state_changed {
        let (profile, brightness, kbd_brightness, label) = match state {
          PowerState::Ac => (
            settings.ac_profile.as_deref().unwrap_or("performance"),
            settings.ac_screen_brightness.unwrap_or(100),
            settings.ac_kbd_brightness.unwrap_or(100),
            "AC power",
          ),
          PowerState::Battery => (
            settings.bat_profile.as_deref().unwrap_or("balanced"),
            settings.bat_screen_brightness.unwrap_or(70),
            settings.bat_kbd_brightness.unwrap_or(33),
            "Battery power",
          ),
          PowerState::LowBattery => (
            settings.low_profile.as_deref().unwrap_or("power-saver"),
            settings.low_screen_brightness.unwrap_or(30),
            settings.low_kbd_brightness.unwrap_or(0),
            "Low battery",
          ),
        };

        set_profile(profile);
        set_brightness(brightness, kbd_brightness);

        send_notification(
          &format!("Power: {}", label),
          &format!("Profile: {}\nBrightness: {}%", profile, brightness),
        );

        last_state = Some(match state {
          PowerState::Ac => PowerState::Ac,
          PowerState::Battery => PowerState::Battery,
          PowerState::LowBattery => PowerState::LowBattery,
        });
      }
    }

    thread::sleep(Duration::from_secs(3));
  }
}
