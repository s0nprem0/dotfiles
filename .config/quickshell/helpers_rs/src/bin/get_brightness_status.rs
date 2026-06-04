use helpers_rs::{brightnessctl_percent, find_kbd_backlight_device, print_json, read_trimmed};
use serde::Serialize;
use std::path::Path;

#[derive(Serialize)]
struct BrightnessStatus {
  screen_brightness_pct: i32,
  kbd_brightness_pct: i32,
  kbd_device: String,
}

fn main() {
  let kbd_device = find_kbd_backlight_device().unwrap_or_default();
  let kbd_brightness_pct = if kbd_device.is_empty() {
    0
  } else {
    brightnessctl_percent(Some(&kbd_device))
  };

  let status = BrightnessStatus {
    screen_brightness_pct: brightnessctl_percent(None),
    kbd_brightness_pct,
    kbd_device,
  };

  print_json(&status);
}
