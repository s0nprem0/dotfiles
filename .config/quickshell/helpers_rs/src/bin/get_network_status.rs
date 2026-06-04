use helpers_rs::{active_wifi_device, print_json, run_cmd, split_nmcli_t_line};
use serde::Serialize;

#[derive(Serialize)]
struct NetworkStatus {
  connected: bool,
  ssid: String,
  signal: i32,
  device: String,
  ip_address: String,
}

fn main() {
  let device = active_wifi_device().unwrap_or_default();
  let mut connected = false;
  let mut ssid = String::new();
  let mut signal = 0;
  let mut ip_address = String::new();

  if let Some(out) = run_cmd("nmcli", &["-t", "-f", "ACTIVE,SSID,SIGNAL,DEVICE", "d", "wifi"]) {
    for line in out.lines() {
      let parts = split_nmcli_t_line(line);
      if parts.len() >= 4 && parts[0] == "yes" {
        connected = true;
        ssid = parts[1].clone();
        signal = parts[2].parse().unwrap_or(0);
      }
    }
  }

  if !device.is_empty() {
    if let Some(out) = run_cmd("nmcli", &["-t", "-f", "IP4.ADDRESS", "d", "show", &device]) {
      for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 2 {
          ip_address = parts[1].clone();
          break;
        }
      }
    }
  }

  let status = NetworkStatus {
    connected,
    ssid,
    signal,
    device,
    ip_address,
  };

  print_json(&status);
}
