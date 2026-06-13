use helpers_rs::run_cmd;
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Deserialize)]
struct HyprctlActiveWindow {
    at: [i32; 2],
    size: [i32; 2],
}

fn screenshot_dir() -> PathBuf {
  let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
  home.join("Pictures/Screenshots")
}

fn timestamp() -> String {
  run_cmd("date", &["+%Y%m%d_%H%M%S"]).unwrap_or_else(|| "unknown".to_string())
}

fn notify(summary: &str, body: &str) {
  let _ = run_cmd("notify-send", &["-a", "Screenshot", summary, body]);
}

fn grim_geometry_arg(geometry: &Option<String>) -> String {
  match geometry {
    Some(g) => format!("-g '{}'", g),
    None => String::new(),
  }
}

fn main() {
  let args: Vec<String> = env::args().collect();
  let mut save = true;
  let mut copy = true;

  let mut arg_idx = 1;
  while arg_idx < args.len() && args[arg_idx].starts_with('-') {
    match args[arg_idx].as_str() {
      "-s" => copy = false,
      "-c" => save = false,
      _ => {
        eprintln!("Usage: screenshot [-s] [-c] [full|region|active]");
        std::process::exit(1);
      }
    }
    arg_idx += 1;
  }

  let mode = args.get(arg_idx).map(|s| s.as_str()).unwrap_or("full");

  let dir = screenshot_dir();
  let _ = fs::create_dir_all(&dir);
  let path = dir.join(format!("{}_{}.png", mode, timestamp()));
  let path_str = path.to_string_lossy().to_string();

  let geometry = match mode {
    "full" => None,
    "region" => {
      let region = run_cmd("slurp", &[]);
      if region.is_none() {
        notify("Screenshot Cancelled", "No region selected.");
        return;
      }
      Some(region.unwrap())
    }
    "active" => {
      let out = run_cmd("hyprctl", &["-j", "activewindow"]).unwrap_or_default();
      match parse_active_window_geometry(&out) {
        Some(g) => Some(g),
        None => {
          notify("Screenshot Failed", "Could not get active window info.");
          return;
        }
      }
    }
    _ => {
      eprintln!("Usage: screenshot [-s] [-c] [full|region|active]");
      std::process::exit(1);
    }
  };

  let geom_arg = grim_geometry_arg(&geometry);
  let label = match mode {
    "full" => "Full screen",
    "region" => "Region",
    "active" => "Active window",
    _ => "Screenshot",
  };

  let result = if save && copy {
    run_cmd("sh", &["-c", &format!("grim {} '{}' && wl-copy < '{}'", geom_arg, path_str, path_str)])
  } else if save {
    run_cmd("sh", &["-c", &format!("grim {} '{}'", geom_arg, path_str)])
  } else if copy {
    run_cmd("sh", &["-c", &format!("grim {} - | wl-copy", geom_arg)])
  } else {
    notify("Screenshot Failed", "No action specified.");
    return;
  };

  match result {
    Some(_) => {
      if save && copy {
        notify("Screenshot Captured!", &format!("{} saved and copied.", label));
      } else if save {
        notify("Screenshot Captured!", &format!("{} saved.", label));
      } else {
        notify("Screenshot Captured!", &format!("{} copied to clipboard.", label));
      }
    }
    None => notify("Screenshot Failed", "Capture command failed."),
  }
}

fn parse_active_window_geometry(json: &str) -> Option<String> {
  let win: HyprctlActiveWindow = serde_json::from_str(json).ok()?;
  Some(format!("{},{},{}x{}", win.at[0], win.at[1], win.size[0], win.size[1]))
}
