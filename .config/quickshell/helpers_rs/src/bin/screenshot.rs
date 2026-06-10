use helpers_rs::run_cmd;
use std::env;
use std::fs;
use std::path::PathBuf;

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
  let path = dir.join(timestamp());
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
  // Parse hyprctl activewindow -j output with simple string search
  // {"at": [x, y], "size": [w, h], ...}
  let at_pos = json.find(r#""at":"#)?;
  let after_at = json[at_pos + 5..].trim_start();
  let x_end = after_at.find(',')?;
  let x: i32 = after_at[1..x_end].trim().parse().ok()?;
  let rest = &after_at[x_end + 1..];
  let y_end = rest.find(']')?;
  let y: i32 = rest[..y_end].trim().parse().ok()?;

  let size_pos = json.find(r#""size":"#)?;
  let after_size = json[size_pos + 7..].trim_start();
  let w_end = after_size.find(',')?;
  let w: i32 = after_size[1..w_end].trim().parse().ok()?;
  let rest2 = &after_size[w_end + 1..];
  let h_end = rest2.find(']')?;
  let h: i32 = rest2[..h_end].trim().parse().ok()?;

  Some(format!("{},{},{}x{}", x, y, w, h))
}
