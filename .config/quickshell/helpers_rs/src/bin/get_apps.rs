use serde::Serialize;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Serialize)]
struct AppEntry {
  id: String,
  name: String,
  icon: String,
  exec: String,
  terminal: bool,
}

fn collect_dirs() -> Vec<PathBuf> {
  let mut dirs = vec![PathBuf::from("/usr/share/applications")];
  if let Ok(home) = std::env::var("HOME") {
    let local = PathBuf::from(home).join(".local/share/applications");
    if local.exists() {
      dirs.push(local);
    }
  }
  dirs
}

fn parse_desktop(path: &Path) -> Option<AppEntry> {
  let content = fs::read_to_string(path).ok()?;
  let id = path.file_name()?.to_str()?.to_string();

  let mut in_desktop = false;
  let mut fields = HashMap::new();

  for line in content.lines() {
    let line = line.trim();
    if line.starts_with('[') {
      in_desktop = line.eq_ignore_ascii_case("[desktop entry]");
      continue;
    }
    if !in_desktop || line.starts_with('#') || line.is_empty() {
      continue;
    }
    if let Some(eq) = line.find('=') {
      let key = line[..eq].trim();
      let val = line[eq + 1..].trim();
      // Skip locale-specific keys (those with [ in the key)
      if !key.contains('[') {
        fields.entry(key.to_lowercase()).or_insert_with(|| val.to_string());
      }
    }
  }

  let type_val = fields.get("type")?;
  if !type_val.eq_ignore_ascii_case("application") {
    return None;
  }

  if fields.get("nodisplay").map(|v| v == "true").unwrap_or(false) {
    return None;
  }

  if fields.get("hidden").map(|v| v == "true").unwrap_or(false) {
    return None;
  }

  let name = fields.get("name").cloned().unwrap_or_default();
  let icon = fields.get("icon").cloned().unwrap_or_default();
  let exec_raw = fields.get("exec").cloned().unwrap_or_default();
  let terminal = fields.get("terminal").map(|v| v == "true").unwrap_or(false);

  // Strip field codes like %f, %u, %F, %U, etc.
  let exec = sanitize_exec(&exec_raw);

  Some(AppEntry { id, name, icon, exec, terminal })
}

fn sanitize_exec(exec: &str) -> String {
  let mut result = String::new();
  let mut chars = exec.chars().peekable();
  while let Some(c) = chars.next() {
    if c == '%' {
      // Skip the field code
      let _ = chars.next();
      continue;
    }
    result.push(c);
  }
  result.trim().to_string()
}

fn main() {
  let mut apps: Vec<AppEntry> = Vec::new();

  for dir in collect_dirs() {
    let Ok(entries) = fs::read_dir(&dir) else { continue };
    for entry in entries.flatten() {
      let path = entry.path();
      if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
        continue;
      }
      if let Some(app) = parse_desktop(&path) {
        apps.push(app);
      }
    }
  }

  apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
  helpers_rs::print_json(&apps);
}
