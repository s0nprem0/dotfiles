use helpers_rs::parse_percent;
use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
struct SinkInfo {
  index: u32,
  name: String,
  description: String,
  volume: i64,
  muted: bool,
  is_bluetooth: bool,
}

#[derive(Serialize)]
struct SourceInfo {
  index: u32,
  name: String,
  description: String,
  volume: i64,
  muted: bool,
}

#[derive(Serialize)]
struct AppInfo {
  index: u32,
  name: String,
  volume: i64,
  muted: bool,
}

#[derive(Serialize)]
struct MediaInfo {
  player: String,
  title: String,
  artist: String,
  art_url: String,
  status: String,
  position: f64,
  length: f64,
}

#[derive(Serialize)]
struct MediaSource {
  name: String,
}

#[derive(Serialize)]
struct Diagnostics {
  pipewire_version: String,
  sample_rate: String,
  output_desc: String,
}

#[derive(Serialize)]
struct AudioStatus {
  default_sink: Option<SinkInfo>,
  default_source: Option<SourceInfo>,
  sinks: Vec<SinkInfo>,
  sources: Vec<SourceInfo>,
  apps: Vec<AppInfo>,
  media: Option<MediaInfo>,
  media_sources: Vec<MediaSource>,
  diagnostics: Diagnostics,
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

fn parse_sinks(sinks_json: &serde_json::Value, default_name: &str) -> (Vec<SinkInfo>, Option<SinkInfo>) {
  let mut sinks = Vec::new();
  let mut default_sink = None;

  if let Some(arr) = sinks_json.as_array() {
    for s in arr {
      let index = s.get("index").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
      let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let description = s.get("description").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
      let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);
      let is_bt = name.to_lowercase().contains("bluez") || name.to_lowercase().contains("bluetooth");

      let sink = SinkInfo { index, name: name.clone(), description, volume: vol, muted, is_bluetooth: is_bt };
      if name == default_name {
        default_sink = Some(SinkInfo { index: sink.index, name: sink.name.clone(), description: sink.description.clone(), volume: sink.volume, muted: sink.muted, is_bluetooth: sink.is_bluetooth });
      }
      sinks.push(sink);
    }
  }

  (sinks, default_sink)
}

fn parse_sources(sources_json: &serde_json::Value, default_name: &str) -> (Vec<SourceInfo>, Option<SourceInfo>) {
  let mut sources = Vec::new();
  let mut default_source = None;

  if let Some(arr) = sources_json.as_array() {
    for s in arr {
      let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("");
      // Skip monitor sources
      if s.get("monitor_of_sink").is_some() || name.contains(".monitor") {
        continue;
      }
      let index = s.get("index").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
      let desc = s.get("description").and_then(|v| v.as_str()).unwrap_or("").to_string();
      let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
      let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

      let source = SourceInfo { index, name: name.to_string(), description: desc, volume: vol, muted };
      if name == default_name {
        default_source = Some(SourceInfo { index: source.index, name: source.name.clone(), description: source.description.clone(), volume: source.volume, muted: source.muted });
      }
      sources.push(source);
    }
  }

  (sources, default_source)
}

fn parse_apps(inputs_json: &serde_json::Value) -> Vec<AppInfo> {
  let mut apps = Vec::new();

  if let Some(arr) = inputs_json.as_array() {
    for s in arr {
      let index = s.get("index").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
      let props = s.get("properties").and_then(|v| v.as_object()).cloned().unwrap_or_default();
      let name = props.get("application.name").and_then(|v| v.as_str()).unwrap_or("Unknown").to_string();
      let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
      let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);
      apps.push(AppInfo { index, name, volume: vol, muted });
    }
  }

  apps
}

fn get_diagnostics() -> Diagnostics {
  let pw_version = Command::new("pactl")
    .args(["--version"])
    .output()
    .ok()
    .and_then(|o| {
      if o.status.success() {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        // Extract version like "15.0.0" from "pactl 15.0.0"
        let parts: Vec<&str> = s.split_whitespace().collect();
        parts.get(1).map(|s| s.to_string())
      } else {
        None
      }
    })
    .unwrap_or_else(|| "unknown".to_string());

  let sample_rate = Command::new("sh")
    .args(["-c", r#"pactl list sinks | grep "Sample Specification" | head -1 | awk '{print $NF}'"#])
    .output()
    .ok()
    .and_then(|o| {
      if o.status.success() {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if s.is_empty() { None } else { Some(s) }
      } else {
        None
      }
    })
    .unwrap_or_else(|| "48kHz".to_string());

  let output_desc = Command::new("sh")
    .args(["-c", r#"pactl get-default-sink 2>/dev/null | xargs -I{} pactl list sinks short 2>/dev/null | grep "{}" | awk '{print $2}'"#])
    .output()
    .ok()
    .and_then(|o| {
      if o.status.success() {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if s.is_empty() { None } else { Some(s) }
      } else {
        None
      }
    })
    .unwrap_or_else(|| "Default".to_string());

  Diagnostics { pipewire_version: pw_version, sample_rate, output_desc }
}

fn get_media_info() -> (Vec<MediaSource>, Option<MediaInfo>) {
  // Read persisted media source selection
  let current_source = std::fs::read_to_string("/tmp/quickshell_current_media_player")
    .ok()
    .map(|s| s.trim().to_string())
    .unwrap_or_default();

  // List players
  let players_output = Command::new("playerctl")
    .args(["-l"])
    .output()
    .ok()
    .and_then(|o| {
      if o.status.success() {
        let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
        if s.is_empty() { None } else { Some(s) }
      } else {
        None
      }
    });

  let media_sources: Vec<MediaSource> = match &players_output {
    Some(out) => out.lines().map(|l| MediaSource { name: l.trim().to_string() }).collect(),
    None => Vec::new(),
  };

  // Determine which player to query
  let active_player = if media_sources.iter().any(|s| s.name == current_source) {
    current_source.clone()
  } else {
    media_sources.first().map(|s| s.name.clone()).unwrap_or_default()
  };

  let media = if !active_player.is_empty() {
    // Fetch metadata: title|artist|artUrl|length
    let metadata = Command::new("playerctl")
      .args(["-p", &active_player, "metadata", "--format", "{{artist}}|{{title}}|{{mpris:artUrl}}|{{mpris:length}}"])
      .output()
      .ok()
      .and_then(|o| {
        if o.status.success() {
          let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
          if s.is_empty() { None } else { Some(s) }
        } else {
          None
        }
      });

    let status = Command::new("playerctl")
      .args(["-p", &active_player, "status"])
      .output()
      .ok()
      .and_then(|o| {
        if o.status.success() {
          let s = String::from_utf8_lossy(&o.stdout).trim().to_string();
          if s == "Playing" || s == "Paused" { Some(s) } else { None }
        } else {
          None
        }
      });

    let position = Command::new("playerctl")
      .args(["-p", &active_player, "position"])
      .output()
      .ok()
      .and_then(|o| {
        if o.status.success() {
          String::from_utf8_lossy(&o.stdout).trim().parse::<f64>().ok()
        } else {
          None
        }
      });

    let (artist, title, art_url, length_us) = match &metadata {
      Some(m) => {
        let parts: Vec<&str> = m.split('|').collect();
        (
          parts.first().unwrap_or(&"").to_string(),
          parts.get(1).unwrap_or(&"").to_string(),
          parts.get(2).unwrap_or(&"").to_string(),
          parts.get(3).unwrap_or(&"0").parse::<f64>().unwrap_or(0.0),
        )
      }
      None => (String::new(), String::new(), String::new(), 0.0),
    };

    Some(MediaInfo {
      player: active_player,
      title,
      artist,
      art_url,
      status: status.unwrap_or_else(|| "Stopped".to_string()),
      position: position.unwrap_or(0.0),
      length: length_us / 1_000_000.0,
    })
  } else {
    None
  };

  (media_sources, media)
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

  let sinks_json = get_pactl_json("sinks");
  let sources_json = get_pactl_json("sources");
  let apps_json = get_pactl_json("sink-inputs");

  let (sinks, default_sink) = parse_sinks(&sinks_json, &default_sink_name);
  let (sources, default_source) = parse_sources(&sources_json, &default_source_name);
  let apps = parse_apps(&apps_json);
  let diagnostics = get_diagnostics();
  let (media_sources, media) = get_media_info();

  let vol = sinks.first().map(|s| s.volume).unwrap_or(0);
  let muted = sinks.first().map(|s| s.muted).unwrap_or(false);

  let status = AudioStatus {
    default_sink,
    default_source,
    sinks,
    sources,
    apps,
    media,
    media_sources,
    diagnostics,
    volume: vol,
    muted,
  };

  helpers_rs::print_json(&status);
}
