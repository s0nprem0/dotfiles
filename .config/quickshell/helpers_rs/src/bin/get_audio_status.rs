use helpers_rs::{parse_percent, print_json};
use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
struct SinkInfo {
  name: String,
  description: String,
  volume: i64,
  muted: bool,
}

#[derive(Serialize)]
struct SourceInfo {
  name: String,
  description: String,
  volume: i64,
  muted: bool,
}

#[derive(Serialize)]
struct AudioStatus {
  default_sink: Option<SinkInfo>,
  default_source: Option<SourceInfo>,
  volume: i64,
  muted: bool,
}

fn get_pactl_json(category: &str) -> serde_json::Value {
  let Ok(output) = Command::new("pactl")
    .args(["-f", "json", "list", category])
    .output()
  else {
    return serde_json::Value::Array(Vec::new());
  };
  if !output.status.success() {
    return serde_json::Value::Array(Vec::new());
  }
  let out_str = String::from_utf8_lossy(&output.stdout);
  if let Ok(val) = serde_json::from_str::<serde_json::Value>(&out_str) {
    if val.is_array() {
      return val;
    } else if val.is_object() {
      return serde_json::Value::Array(vec![val]);
    }
  }
  serde_json::Value::Array(Vec::new())
}

fn parse_volume(vol_obj: &serde_json::Value) -> i64 {
  if let Some(obj) = vol_obj.as_object() {
    for (_chan, val_dict) in obj {
      if let Some(val_str) = val_dict.get("value_percent").and_then(|v| v.as_str()) {
        if let Some(vol) = parse_percent(val_str) {
          return vol;
        }
      }
    }
  }
  0
}

fn main() {
  let mut default_sink_name = String::new();
  let mut default_source_name = String::new();

  if let Ok(output) = Command::new("pactl").arg("info").output() {
    if output.status.success() {
      let out_str = String::from_utf8_lossy(&output.stdout);
      for line in out_str.lines() {
        if let Some(s) = line.strip_prefix("Default Sink:") {
          default_sink_name = s.trim().to_string();
        } else if let Some(s) = line.strip_prefix("Default Source:") {
          default_source_name = s.trim().to_string();
        }
      }
    }
  }

  let mut default_sink: Option<SinkInfo> = None;
  let mut default_source: Option<SourceInfo> = None;

  if let Some(sinks) = get_pactl_json("sinks").as_array() {
    for s in sinks {
      let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let description = s.get("description").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
      let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

      let sink = SinkInfo { name: name.clone(), description, volume: vol, muted };
      if name == default_sink_name {
        default_sink = Some(sink);
      }
    }
  }

  if let Some(sources) = get_pactl_json("sources").as_array() {
    for s in sources {
      let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("");
      if s.get("monitor_of_sink").is_some() || name.contains(".monitor") {
        continue;
      }
      let description = s.get("description").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
      let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

      let source = SourceInfo { name: name.to_string(), description, volume: vol, muted };
      if name == default_source_name {
        default_source = Some(source);
      }
    }
  }

  let vol = default_sink.as_ref().map(|s| s.volume).unwrap_or(0);
  let muted = default_sink.as_ref().map(|s| s.muted).unwrap_or(false);

  let status = AudioStatus { default_sink, default_source, volume: vol, muted };
  print_json(&status);
}
