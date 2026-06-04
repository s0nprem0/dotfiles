use helpers_rs::print_json;
use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
struct NotifStatus {
  count: i32,
  dnd: bool,
}

fn main() {
  let mut count = 0;
  let mut dnd = false;

  if let Ok(output) = Command::new("swaync-client").arg("--count").output() {
    if output.status.success() {
      if let Ok(s) = String::from_utf8(output.stdout) {
        count = s.trim().parse().unwrap_or(0);
      }
    }
  }

  if let Ok(output) = Command::new("swaync-client").arg("--get-dnd").output() {
    if output.status.success() {
      if let Ok(s) = String::from_utf8(output.stdout) {
        dnd = s.trim() == "true" || s.trim() == "1";
      }
    }
  }

  let status = NotifStatus { count, dnd };
  print_json(&status);
}
