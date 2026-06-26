use primo::cache_dir;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[derive(Serialize, Deserialize, Clone)]
struct AppInfo {
    name: String,
    exec: String,
    icon: String,
    desktop_id: String,
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

#[derive(Serialize, Deserialize, Clone)]
struct Bookmark {
    url: String,
    name: String,
    timestamp: u64,
}

#[derive(Serialize, Deserialize, Clone)]
struct GitRepo {
    name: String,
    html_url: String,
    description: String,
    updated_at: String,
    #[serde(default)]
    stargazers_count: u32,
}

#[derive(Serialize)]
struct MainResponse {
    most_used: Vec<AppInfo>,
    all_apps: Vec<AppInfo>,
    web_history: Vec<WebHistoryItem>,
    file_history: Vec<FileHistoryItem>,
}

struct Storage {
    db_path: PathBuf,
}

impl Storage {
    fn new() -> Self {
        let db_path = cache_dir().join("apps.db");
        let conn = rusqlite::Connection::open(&db_path)
            .unwrap_or_else(|_| rusqlite::Connection::open(":memory:").unwrap());
        Storage::init_db(&conn);
        Self { db_path }
    }

    fn connection(&self) -> rusqlite::Result<rusqlite::Connection> {
        rusqlite::Connection::open(&self.db_path)
    }

fn init_db(conn: &rusqlite::Connection) {
        let _ = conn.execute(
            "CREATE TABLE IF NOT EXISTS bookmarks (
                url TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )",
            [],
        );
        let _ = conn.execute(
            "CREATE TABLE IF NOT EXISTS file_index (
                path TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )",
            [],
        );
        let _ = conn.execute(
            "CREATE TABLE IF NOT EXISTS git_repos (
                name TEXT PRIMARY KEY,
                html_url TEXT NOT NULL,
                description TEXT,
                updated_at TEXT NOT NULL,
                stargazers_count INTEGER DEFAULT 0
            )",
            [],
        );
        let _ = conn.execute(
            "CREATE TABLE IF NOT EXISTS web_history (
                query TEXT, engine TEXT, url TEXT, timestamp INTEGER,
                PRIMARY KEY (query, engine)
            )",
            [],
        );
        let _ = conn.execute(
            "CREATE TABLE IF NOT EXISTS file_history (
                path TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                timestamp INTEGER
            )",
            [],
        );
    }

    fn load_bookmarks(&self) -> Vec<Bookmark> {
        let conn = match self.connection() {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare("SELECT url, name, timestamp FROM bookmarks ORDER BY timestamp DESC") {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(Bookmark {
                url: row.get(0)?,
                name: row.get(1)?,
                timestamp: row.get(2)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn add_bookmark(&self, url: &str, name: &str, timestamp: u64) -> bool {
        match self.connection() {
            Ok(conn) => {
                conn.execute(
                    "INSERT OR REPLACE INTO bookmarks (url, name, timestamp) VALUES (?1, ?2, ?3)",
                    rusqlite::params![url, name, timestamp],
                ).is_ok()
            }
            Err(_) => false,
        }
    }

    fn delete_bookmark(&self, url: &str) -> bool {
        match self.connection() {
            Ok(conn) => conn.execute("DELETE FROM bookmarks WHERE url = ?1", rusqlite::params![url]).is_ok(),
            Err(_) => false,
        }
    }

    fn load_file_index(&self) -> Vec<FileIndexEntry> {
        let conn = match self.connection() {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare("SELECT path, name FROM file_index") {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(FileIndexEntry {
                path: row.get(0)?,
                name: row.get(1)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn save_file_index(&self, entries: &[FileIndexEntry]) -> bool {
        match self.connection() {
            Ok(mut conn) => {
                let tx = match conn.transaction() {
                    Ok(t) => t,
                    Err(_) => return false,
                };
                let _ = tx.execute("DELETE FROM file_index", []);
                for entry in entries {
                    let _ = tx.execute(
                        "INSERT OR REPLACE INTO file_index (path, name) VALUES (?1, ?2)",
                        rusqlite::params![entry.path, entry.name],
                    );
                }
                tx.commit().is_ok()
            }
            Err(_) => false,
        }
    }

    fn load_git_repos(&self) -> Vec<GitRepo> {
        let conn = match self.connection() {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT name, html_url, description, updated_at, stargazers_count FROM git_repos ORDER BY updated_at DESC"
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(GitRepo {
                name: row.get(0)?,
                html_url: row.get(1)?,
                description: row.get(2)?,
                updated_at: row.get(3)?,
                stargazers_count: row.get(4)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn load_web_history(&self) -> Vec<WebHistoryItem> {
        let conn = match self.connection() {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT query, engine, url FROM web_history ORDER BY timestamp DESC LIMIT 50"
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(WebHistoryItem {
                query: row.get(0)?,
                engine: row.get(1)?,
                url: row.get(2)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn add_web_history(&self, item: &WebHistoryItem) -> bool {
        match self.connection() {
            Ok(conn) => {
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                conn.execute(
                    "INSERT OR REPLACE INTO web_history (query, engine, url, timestamp) VALUES (?1, ?2, ?3, ?4)",
                    rusqlite::params![item.query, item.engine, item.url, timestamp],
                ).is_ok()
            }
            Err(_) => false,
        }
    }

    fn load_file_history(&self) -> Vec<FileHistoryItem> {
        let conn = match self.connection() {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT path, name, timestamp FROM file_history ORDER BY timestamp DESC LIMIT 50"
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(FileHistoryItem {
                path: row.get(0)?,
                name: row.get(1)?,
                timestamp: row.get(2)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn add_file_history(&self, path: &str) -> bool {
        match self.connection() {
            Ok(conn) => {
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                let name = PathBuf::from(path)
                    .file_name()
                    .and_then(|f| f.to_str())
                    .unwrap_or(path)
                    .to_string();
                conn.execute(
                    "INSERT OR REPLACE INTO file_history (path, name, timestamp) VALUES (?1, ?2, ?3)",
                    rusqlite::params![path, name, timestamp],
                ).is_ok()
            }
            Err(_) => false,
        }
    }

    fn save_git_repos(&self, repos: &[GitRepo]) -> bool {
        match self.connection() {
            Ok(mut conn) => {
                let tx = match conn.transaction() {
                    Ok(t) => t,
                    Err(_) => return false,
                };
                let _ = tx.execute("DELETE FROM git_repos", []);
                for repo in repos {
                    let _ = tx.execute(
                        "INSERT OR REPLACE INTO git_repos (name, html_url, description, updated_at, stargazers_count) VALUES (?1, ?2, ?3, ?4, ?5)",
                        rusqlite::params![repo.name, repo.html_url, repo.description, repo.updated_at, repo.stargazers_count],
                    );
                }
                tx.commit().is_ok()
            }
            Err(_) => false,
        }
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
    if !q.starts_with('!') {
        return None;
    }

    let (trigger, search_text) = match q.find(' ') {
        None => (q.to_lowercase(), ""),
        Some(idx) => (q[..idx].to_lowercase(), q[idx + 1..].trim()),
    };

    let (engine_name, search_url, query_text) = match trigger.as_str() {
        "!yt" | "!youtube" => (
            "youtube",
            "https://www.youtube.com/results?search_query=",
            search_text,
        ),
        "!g" | "!google" => ("google", "https://www.google.com/search?q=", search_text),
        "!gh" | "!github" => ("github", "https://github.com/search?q=", search_text),
        "!w" | "!wiki" | "!wikipedia" => (
            "wikipedia",
            "https://en.wikipedia.org/wiki/Special:Search?search=",
            search_text,
        ),
        _ => (
            "duckduckgo",
            "https://duckduckgo.com/?q=",
            if search_text.is_empty() { &q[1..] } else { q },
        ),
    };

    if query_text.is_empty() {
        return None;
    }

    Some(WebHistoryItem {
        query: query_text.to_string(),
        engine: engine_name.to_string(),
        url: format!("{}{}", search_url, url_encode(query_text)),
    })
}

fn parse_desktop_file(path: &PathBuf, desktop_id: &str) -> Option<AppInfo> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut name = None;
    let mut exec = None;
    let mut icon = None;
    let mut no_display = false;
    let mut in_desktop_entry = false;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line.contains("Desktop Entry");
            continue;
        }
        if !in_desktop_entry {
            continue;
        }

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
                    if val.eq_ignore_ascii_case("true") {
                        no_display = true;
                    }
                }
                _ => {}
            }
        }
    }

    if no_display {
        return None;
    }

    Some(AppInfo {
        name: name?,
        exec: exec?,
        icon: icon.unwrap_or_default(),
        desktop_id: desktop_id.to_string(),
        count: 0,
    })
}

fn fetch_github_repos(token: Option<&str>) -> Result<Vec<GitRepo>, Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::new();
    let url = "https://api.github.com/user/repos?per_page=100";
    
    let mut req = client.get(url);
    if let Some(t) = token {
        req = req.bearer_auth(t);
    }
    
    let repos: Vec<GitRepo> = req.send()?.json()?;
    Ok(repos)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let storage = Storage::new();

    if args.len() > 1 {
        match args[1].as_str() {
            "--clear-web-history" => {
                match storage.connection() {
                    Ok(conn) => {
                        let _ = conn.execute("DELETE FROM web_history", []);
                        println!("{}", serde_json::json!({"status": "cleared"}));
                    }
                    Err(e) => eprintln!("Error clearing web history: {}", e),
                }
                return;
            }
            "--clear-file-history" => {
                match storage.connection() {
                    Ok(conn) => {
                        let _ = conn.execute("DELETE FROM file_history", []);
                        println!("{}", serde_json::json!({"status": "cleared"}));
                    }
                    Err(e) => eprintln!("Error clearing file history: {}", e),
                }
                return;
            }
            "--index-files" => {
                let home = match std::env::var("HOME") {
                    Ok(h) => h,
                    Err(_) => {
                        eprintln!("HOME not set, skipping file indexing");
                        return;
                    }
                };
                let out = Command::new("fd")
                    .args([
                        "--type", "f",
                        "--hidden",
                        "--exclude", ".git",
                        "--exclude", "node_modules",
                        "--exclude", ".cache",
                        "--exclude", "target",
                        "--max-depth", "8",
                    ])
                    .current_dir(&home)
                    .output();

                if let Ok(output) = out {
                    let entries: Vec<FileIndexEntry> = String::from_utf8_lossy(&output.stdout)
                        .lines()
                        .map(|line| {
                            let name = PathBuf::from(line)
                                .file_name()
                                .and_then(|f| f.to_str())
                                .unwrap_or(line)
                                .to_string();
                            FileIndexEntry {
                                path: format!("~/{}", line),
                                name,
                            }
                        })
                        .collect();

                    storage.save_file_index(&entries);
                    println!("{}", serde_json::json!({"indexed": entries.len()}));
                }
                return;
            }
            "--search-files" if args.len() > 2 => {
                let query = &args[2];
                let entries = storage.load_file_index();
                if !entries.is_empty() {
                    let mut child = Command::new("fzf")
                        .args(["-f", query])
                        .stdin(Stdio::piped())
                        .stdout(Stdio::piped())
                        .spawn().ok();

                    if let Some(ref mut child_proc) = child {
                        if let Some(ref mut stdin) = child_proc.stdin {
                            for entry in &entries {
                                let _ = writeln!(stdin, "{}", entry.path);
                            }
                        }
                    }

                    if let Some(child_proc) = child {
                        if let Ok(output) = child_proc.wait_with_output() {
                            let entry_map: HashMap<&str, &FileIndexEntry> =
                                entries.iter().map(|e| (e.path.as_str(), e)).collect();

                            let results: Vec<&FileIndexEntry> =
                                String::from_utf8_lossy(&output.stdout)
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
            "--list-repos" => {
                let repos = storage.load_git_repos();
                let _ = serde_json::to_writer(std::io::stdout(), &repos);
                return;
            }
            "--search-repos" if args.len() > 2 => {
                let query = &args[2];
                let repos = storage.load_git_repos();
                if !repos.is_empty() {
                    let filtered: Vec<&GitRepo> = repos
                        .iter()
                        .filter(|r| {
                            r.name.to_lowercase().contains(&query.to_lowercase()) ||
                            r.description.to_lowercase().contains(&query.to_lowercase())
                        })
                        .take(20)
                        .collect();
                    let _ = serde_json::to_writer(std::io::stdout(), &filtered);
                } else {
                    println!("[]");
                }
                return;
            }
            "--add-bookmark" if args.len() > 2 => {
                let url = &args[2];
                let name = url
                    .trim_start_matches("https://")
                    .trim_start_matches("http://")
                    .trim_start_matches("github.com/")
                    .trim_start_matches("www.")
                    .split('/')
                    .next()
                    .unwrap_or(url)
                    .to_string();
                
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                
                storage.add_bookmark(url, &name, timestamp);
                println!("{}", serde_json::json!({"status": "added"}));
                return;
            }
            "--delete-bookmark" if args.len() > 2 => {
                let url = &args[2];
                storage.delete_bookmark(url);
                println!("{}", serde_json::json!({"status": "deleted"}));
                return;
            }
            "--get-bookmarks" => {
                let bookmarks = storage.load_bookmarks();
                let _ = serde_json::to_writer(std::io::stdout(), &bookmarks);
                return;
            }
            "--fetch-repos" => {
                let token = std::env::var("GITHUB_TOKEN").ok();
                if token.as_deref().map_or(true, |t| t.is_empty()) {
                    println!("{}", serde_json::json!({"status": "error", "message": "GITHUB_TOKEN not set"}));
                    return;
                }
                match fetch_github_repos(token.as_deref()) {
                    Ok(repos) => {
                        storage.save_git_repos(&repos);
                        println!("{}", serde_json::json!({"status": "fetched", "count": repos.len()}));
                    }
                    Err(e) => {
                        eprintln!("Error fetching repos: {}", e);
                        println!("{}", serde_json::json!({"status": "error", "message": e.to_string()}));
                    }
                }
                return;
            }
            "--web-search" if args.len() > 2 => {
                let query = &args[2];
                if let Some(item) = parse_web_search(query) {
                    storage.add_web_history(&item);
                    println!("{}", serde_json::json!({"status": "added", "query": item.query}));
                } else {
                    println!("{}", serde_json::json!({"status": "skipped", "reason": "invalid query"}));
                }
                return;
            }
            "--open-file" if args.len() > 2 => {
                let path = &args[2];
                storage.add_file_history(path);
                println!("{}", serde_json::json!({"status": "added"}));
                return;
            }
            _ => {}
        }
    }

    let home = match std::env::var("HOME") {
        Ok(h) => h,
        Err(_) => {
            eprintln!("HOME not set, cannot scan applications");
            std::process::exit(1);
        }
    };
    let usage_path = PathBuf::from(&home).join(".cache/quickshell/app_usage.json");
    let usage_map: HashMap<String, u32> = primo::state_file::read_json(&usage_path).unwrap_or_default();
    let mut apps: HashMap<String, AppInfo> = HashMap::new();

    let paths = [
        "/usr/share/applications".to_string(),
        format!("{}/.local/share/applications", home),
        "/var/lib/flatpak/exports/share/applications".to_string(),
        format!("{}/.local/share/flatpak/exports/share/applications", home),
    ];

    for dir_path in &paths {
        let path = PathBuf::from(dir_path);
        if !path.exists() {
            continue;
        }
        if let Ok(entries) = std::fs::read_dir(&path) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.extension().map_or(false, |ext| ext == "desktop") {
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

    let mut most_used: Vec<AppInfo> = all_apps
        .iter()
        .filter(|app| app.count > 0)
        .cloned()
        .collect();
    most_used.sort_by(|a, b| {
        b.count
            .cmp(&a.count)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });
    most_used.truncate(5);

    let web_history = storage.load_web_history();
    let file_history = storage.load_file_history();

    let _ = serde_json::to_writer(
        std::io::stdout(),
        &MainResponse {
            most_used,
            all_apps,
            web_history,
            file_history,
        },
    );
}