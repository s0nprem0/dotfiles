use helpers_rs::{find_kbd_backlight_device, run_cmd};
use std::env;

fn find_screen_device() -> Option<String> {
  let out = run_cmd("brightnessctl", &["-l"])?;
  for line in out.lines() {
    if line.contains("backlight") {
      let parts: Vec<&str> = line.split('\'').collect();
      if parts.len() >= 2 && !parts[1].is_empty() {
        return Some(parts[1].to_string());
      }
    }
  }
  None
}

fn current_pct(device: &str) -> i32 {
  let raw = run_cmd("brightnessctl", &["-d", device, "get"])
    .and_then(|s| s.trim().parse::<f64>().ok())
    .unwrap_or(0.0);
  let max = run_cmd("brightnessctl", &["-d", device, "max"])
    .and_then(|s| s.trim().parse::<f64>().ok())
    .unwrap_or(1.0);
  if max > 0.0 {
    (raw / max * 100.0).round() as i32
  } else {
    0
  }
}

fn notify(pct: i32, label: &str) {
  let _ = run_cmd("notify-send", &[
    "-h", &format!("int:value:{}", pct.clamp(0, 100)),
    "-u", "low",
    "-t", "1000",
    label,
    &format!("{}%", pct),
  ]);
}

fn main() {
  let args: Vec<String> = env::args().collect();
  if args.len() < 3 {
    eprintln!("Usage: osd [screen|kbd] [up|down]");
    std::process::exit(1);
  }

  let target = &args[1];
  let action = &args[2];

  match target.as_str() {
    "screen" => {
      let device = match find_screen_device() {
        Some(d) => d,
        None => {
          eprintln!("No backlight device found");
          std::process::exit(1);
        }
      };
      let current = current_pct(&device);
      let new = match action.as_str() {
        "up" => (current + 10).min(100),
        "down" => (current - 10).max(0),
        _ => { eprintln!("Usage: osd screen [up|down]"); std::process::exit(1); }
      };
      if new != current {
        let _ = run_cmd("brightnessctl", &["-d", &device, "set", &format!("{}%", new)]);
      }
      notify(new, "Brightness");
    }
    "kbd" => {
      let device = match find_kbd_backlight_device() {
        Some(d) => d,
        None => {
          eprintln!("No kbd backlight device found");
          std::process::exit(1);
        }
      };
      let max = run_cmd("brightnessctl", &["-d", &device, "max"])
        .and_then(|s| s.trim().parse::<i32>().ok())
        .unwrap_or(1);
      match action.as_str() {
        "up" => {
          let cur = run_cmd("brightnessctl", &["-d", &device, "get"])
            .and_then(|s| s.trim().parse::<i32>().ok())
            .unwrap_or(0);
          let new = (cur + 1).min(max);
          let _ = run_cmd("brightnessctl", &["-d", &device, "set", &format!("{}", new)]);
          let pct = if max > 0 { (new as f64 / max as f64 * 100.0).round() as i32 } else { 0 };
          notify(pct, "Keyboard Backlight");
        }
        "down" => {
          let cur = run_cmd("brightnessctl", &["-d", &device, "get"])
            .and_then(|s| s.trim().parse::<i32>().ok())
            .unwrap_or(0);
          let new = (cur - 1).max(0);
          let _ = run_cmd("brightnessctl", &["-d", &device, "set", &format!("{}", new)]);
          let pct = if max > 0 { (new as f64 / max as f64 * 100.0).round() as i32 } else { 0 };
          notify(pct, "Keyboard Backlight");
        }
        _ => { eprintln!("Usage: osd kbd [up|down]"); std::process::exit(1); }
      }
    }
    _ => {
      eprintln!("Usage: osd [screen|kbd] [up|down]");
      std::process::exit(1);
    }
  }
}
