use helpers_rs::{battery_snapshot, print_json, round_to};
use serde::Serialize;

#[derive(Serialize)]
struct BatteryStatus {
  capacity: i32,
  status: String,
  health: f64,
  power_draw_w: f64,
  time_remaining: String,
}

fn main() {
  let battery = battery_snapshot();

  let health = if battery.full_design > 0.0 {
    (battery.full / battery.full_design) * 100.0
  } else {
    100.0
  };

  let time_remaining = if battery.status == "Charging" && battery.rate > 0.0 {
    let rem = (battery.full - battery.now).max(0.0);
    let hours = rem / battery.rate;
    format!("{}h {:02}m", hours as i32, ((hours - hours as i32 as f64) * 60.0) as i32)
  } else if battery.status == "Discharging" && battery.rate > 0.0 {
    let hours = battery.now / battery.rate;
    format!("{}h {:02}m", hours as i32, ((hours - hours as i32 as f64) * 60.0) as i32)
  } else if battery.status == "Full" {
    "Full".to_string()
  } else {
    "N/A".to_string()
  };

  let status = BatteryStatus {
    capacity: battery.capacity,
    status: battery.status,
    health: round_to(health, 10.0),
    power_draw_w: round_to(battery.power_w, 100.0),
    time_remaining,
  };

  print_json(&status);
}
