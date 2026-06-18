use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[derive(Serialize, Deserialize, Clone)]
struct AppInfo {
    name: String,
    exec: String,
    icon: String,
    desktop_id: String, // REQUIRED: Needed by the QML frontend
    #[serde(default)]
    count: u32,
}

#[derive(Serialize, Deserialize, Clone)]
struct WebHistoryItem {
    query: String,
    engine: String,
    url: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct FileHistoryItem {
    path: String,
    name: String,
    timestamp: u64,
}

#[derive(Serialize, Deserialize, Clone)]
struct FileIndexEntry {
    path: String,
    name: String,
}

#[derive(Serialize)]
struct MainResponse {
    most_used: Vec<AppInfo>,
    all_apps: Vec<AppInfo>,
    web_history: Vec<WebHistoryItem>,
    file_history: Vec<FileHistoryItem>,
}

// ── STATE & CACHE HELPERS ──
struct Storage {
    cache_dir: PathBuf,
}

impl Storage {
    fn new(home: &str) -> Self {
        let cache_dir = Path::new(home).join(".cache/quickshell");
        let _ = fs::create_dir_all(&cache_dir);
        Self { cache_dir }
    }

    fn load_json<T: serde::de::DeserializeOwned>(&self, file_name: &str) -> Option<T> {
        let path = self.cache_dir.join(file_name);
        if !path.exists() { return None; }
        let content = fs::read_to_string(path).ok()?;
        serde_json::from_str(&content).ok()
    }

    fn save_json<T: serde::Serialize>(&self, file_name: &str, data: &T) {
        let path = self.cache_dir.join(file_name);
        if let Ok(serialized) = serde_json::to_string(data) {
            let _ = fs::write(path, serialized);
        }
    }

    fn clear_file(&self, file_name: &str) {
        let path = self.cache_dir.join(file_name);
        let _ = fs::write(path, "[]");
    }
}

fn url_encode(input: &str) -> String {
    let mut encoded = String::with_capacity(input.len() * 3);
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(byte as char);
            }
            b' ' => encoded.push('+'),
            _ => encoded.push_str(&format!("%{:02X}", byte)),
        }
    }
    encoded
}

fn parse_web_search(query: &str) -> Option<WebHistoryItem> {
    let q = query.trim();
    if !q.starts_with('!') { return None; }

    let (trigger, search_text) = match q.find(' ') {
        None => (q.to_lowercase(), ""),
        Some(idx) => (q[..idx].to_lowercase(), q[idx + 1..].trim()),
    };

    let (engine_name, search_url, query_text) = match trigger.as_str() {
        "!yt" | "!youtube" => ("youtube", "https://www.youtube.com/results?search_query=", search_text),
        "!g" | "!google"   => ("google", "https://www.google.com/search?q=", search_text),
        "!gh" | "!github"  => ("github", "https://github.com/search?q=", search_text),
        "!w" | "!wiki" | "!wikipedia" => ("wikipedia", "https://en.wikipedia.org/wiki/Special:Search?search=", search_text),
        _ => ("duckduckgo", "https://duckduckgo.com/?q=", if search_text.is_empty() { &q[1..] } else { q }),
    };

    if query_text.is_empty() { return None; }

    Some(WebHistoryItem {
        query: query_text.to_string(),
        engine: engine_name.to_string(),
        url: format!("{}{}", search_url, url_encode(query_text)),
    })
}

// FIX: Hardened desktop parsing to capture all apps
fn parse_desktop_file(path: &Path, desktop_id: &str) -> Option<AppInfo> {
    let content = fs::read_to_string(path).ok()?;
    let mut name = None;
    let mut exec = None;
    let mut icon = None;
    let mut no_display = false;
    let mut in_desktop_entry = false;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') { continue; }

        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line.contains("Desktop Entry");
            continue;
        }
        if !in_desktop_entry { continue; }

        if let Some(pos) = line.find('=') {
            let key = line[..pos].trim();
            let val = line[pos + 1..].trim();

            match key {
                "Name" if name.is_none() => name = Some(val.to_string()),
                "Exec" if exec.is_none() => {
                    let cleaned = val
                        .split_whitespace()
                        .filter(|arg| !arg.starts_with('%'))
                        .collect::<Vec<_>>()
                        .join(" ");
                    exec = Some(cleaned);
                }
                "Icon" if icon.is_none() => icon = Some(val.to_string()),
                "NoDisplay" => {
                    if val.eq_ignore_ascii_case("true") { no_display = true; }
                }
                _ => {}
            }
        }
    }

    if no_display { return None; }

    Some(AppInfo {
        name: name?,
        exec: exec?,
        icon: icon.unwrap_or_default(),
        desktop_id: desktop_id.to_string(),
        count: 0,
    })
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    // Safely unwrap HOME or fail fast. Do not use an empty string as a fallback for filesystem crawling.
    let home = std::env::var("HOME").expect("CRITICAL: HOME environment variable is not set.");
    let storage = Storage::new(&home);

    if args.len() > 1 {
        match args[1].as_str() {
            "--clear-history" => {
                storage.clear_file("web_search_history.json");
                return;
            }
            "--clear-file-history" => {
                storage.clear_file("file_history.json");
                return;
            }
            "--index-files" => {
                let out = Command::new("fd")
                    .args(["--type", "f", "--hidden", "--exclude", ".git", "--exclude", "node_modules", "--exclude", ".cache", "--exclude", "target", "--max-depth", "8"])
                    .current_dir(&home)
                    .output();

                if let Ok(output) = out {
                    let entries: Vec<FileIndexEntry> = String::from_utf8_lossy(&output.stdout)
                        .lines()
                        .map(|line| {
                            let name = Path::new(line)
                                .file_name()
                                .and_then(|f| f.to_str())
                                .unwrap_or(line)
                                .to_string();
                            FileIndexEntry { path: format!("~/{}", line), name }
                        })
                        .collect();

                    storage.save_json("file_index.json", &entries);
                    println!("{}", serde_json::json!({"indexed": entries.len()}));
                }
                return;
            }
            "--search-files" if args.len() > 2 => {
                let query = &args[2];
                if let Some(entries) = storage.load_json::<Vec<FileIndexEntry>>("file_index.json") {
                    let mut child = Command::new("fzf")
                        .args(["-f", query])
                        .stdin(Stdio::piped())
                        .stdout(Stdio::piped())
                        .spawn()
                        .ok();

                    if let Some(ref mut child_proc) = child {
                        if let Some(ref mut stdin) = child_proc.stdin {
                            for entry in &entries {
                                let _ = writeln!(stdin, "{}", entry.path);
                            }
                        }
                    }

                    if let Some(child_proc) = child {
                        if let Ok(output) = child_proc.wait_with_output() {
                            // FIX: Replaced slow Iterator string matching with an O(1) HashMap lookup
                            let entry_map: HashMap<&str, &FileIndexEntry> = entries
                                .iter()
                                .map(|e| (e.path.as_str(), e))
                                .collect();

                            let results: Vec<&FileIndexEntry> = String::from_utf8_lossy(&output.stdout)
                                .lines()
                                .filter_map(|line| entry_map.get(line).copied())
                                .take(50)
                                .collect();

                            let _ = serde_json::to_writer(std::io::stdout(), &results);
                            return;
                        }
                    }
                }
                println!("[]");
                return;
            }
            "--open-file" if args.len() > 2 => {
                let file_path = &args[2];
                let mut history = storage.load_json::<Vec<FileHistoryItem>>("file_history.json").unwrap_or_default();

                let name = Path::new(file_path)
                    .file_name()
                    .and_then(|f| f.to_str())
                    .unwrap_or(file_path)
                    .to_string();

                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();

                history.retain(|x| x.path != *file_path);
                history.insert(0, FileHistoryItem { path: file_path.to_string(), name, timestamp });
                history.truncate(30);

                storage.save_json("file_history.json", &history);

                let open_path = if file_path.starts_with("~/") {
                    format!("{}/{}", home, &file_path[2..])
                } else {
                    file_path.to_string()
                };

                // FIX: Use xdg-open instead of thunar so non-directory files open correctly
                let _ = Command::new("xdg-open").arg(&open_path).status();
                return;
            }
            "--file-history" => {
                let history = storage.load_json::<Vec<FileHistoryItem>>("file_history.json").unwrap_or_default();
                let _ = serde_json::to_writer(std::io::stdout(), &history);
                return;
            }
            "--launch" if args.len() > 2 => {
                let app_name = &args[2];
                let mut usage_map = storage.load_json::<HashMap<String, u32>>("app_usage.json").unwrap_or_default();
                *usage_map.entry(app_name.clone()).or_insert(0) += 1;
                storage.save_json("app_usage.json", &usage_map);
                return;
            }
            "--web-search" if args.len() > 2 => {
                let query = &args[2];
                if let Some(item) = parse_web_search(query) {
                    let mut history = storage.load_json::<Vec<WebHistoryItem>>("web_search_history.json").unwrap_or_default();

                    history.retain(|x| !(x.query.to_lowercase() == item.query.to_lowercase() && x.engine == item.engine));
                    history.insert(0, item.clone());
                    history.truncate(20);

                    storage.save_json("web_search_history.json", &history);

                    let _ = Command::new("xdg-open").arg(&item.url).status();
                    let _ = Command::new("hyprctl").args(["dispatch", "workspace", "1"]).status();
                }
                return;
            }
            _ => {}
        }
    }

    let usage_map = storage.load_json::<HashMap<String, u32>>("app_usage.json").unwrap_or_default();
    let mut apps: HashMap<String, AppInfo> = HashMap::new();

    let paths = [
        "/usr/share/applications".to_string(),
        format!("{}/.local/share/applications", home),
        "/var/lib/flatpak/exports/share/applications".to_string(),
        format!("{}/.local/share/flatpak/exports/share/applications", home),
    ];

    for dir_path in &paths {
        let path = Path::new(dir_path);
        if !path.exists() { continue; }
        if let Ok(entries) = fs::read_dir(path) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.extension().map_or(false, |ext| ext == "desktop") {
                    // FIX: Pass the desktop_id cleanly to the parser
                    if let Some(file_name) = p.file_name().and_then(|f| f.to_str()) {
                        if let Some(mut app_info) = parse_desktop_file(&p, file_name) {
                            if let Some(&count) = usage_map.get(&app_info.name) {
                                app_info.count = count;
                            }
                            apps.insert(file_name.to_string(), app_info);
                        }
                    }
                }
            }
        }
    }

    let mut all_apps: Vec<AppInfo> = apps.into_values().collect();
    all_apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    let mut most_used: Vec<AppInfo> = all_apps.iter().filter(|app| app.count > 0).cloned().collect();
    most_used.sort_by(|a, b| b.count.cmp(&a.count).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())));
    most_used.truncate(5);

    let web_history = storage.load_json::<Vec<WebHistoryItem>>("web_search_history.json").unwrap_or_default();
    let file_history = storage.load_json::<Vec<FileHistoryItem>>("file_history.json").unwrap_or_default();

    let _ = serde_json::to_writer(
        std::io::stdout(),
        &MainResponse { most_used, all_apps, web_history, file_history },
    );
}
