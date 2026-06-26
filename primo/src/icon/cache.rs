use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

use super::desktop::DesktopEntry;
use super::theme::ThemeCache;

const CACHE_TTL: Duration = Duration::from_secs(300);

#[derive(Debug)]
pub struct CachedDesktopEntry {
    pub entry: DesktopEntry,
    pub expires_at: Instant,
}

#[derive(Debug)]
pub struct CachedIconPath {
    pub path: PathBuf,
    pub expires_at: Instant,
}

#[derive(Debug, Default)]
pub struct IconCache {
    pub desktop_entries: HashMap<String, CachedDesktopEntry>,
    pub icon_paths: HashMap<String, CachedIconPath>,
    pub wm_class_index: HashMap<String, String>,
    pub exec_index: HashMap<String, String>,
    pub flatpak_id_index: HashMap<String, String>,
    pub snap_id_index: HashMap<String, String>,
    pub theme_cache: Option<Arc<RwLock<ThemeCache>>>,
}

impl IconCache {
    pub fn new() -> Self {
        Self::default()
    }
    
    pub fn get_desktop_entry(&self, desktop_id: &str) -> Option<&DesktopEntry> {
        self.desktop_entries
            .get(desktop_id)
            .filter(|cached| cached.expires_at.elapsed() < CACHE_TTL)
            .map(|cached| &cached.entry)
    }
    
    pub fn set_desktop_entry(&mut self, entry: DesktopEntry) {
        let desktop_id = entry.id.to_string();
        self.desktop_entries.insert(
            desktop_id.clone(),
            CachedDesktopEntry {
                entry,
                expires_at: Instant::now() + CACHE_TTL,
            },
        );
    }
    
    pub fn get_icon_path(&self, icon_name: &str) -> Option<&PathBuf> {
        self.icon_paths
            .get(icon_name)
            .filter(|cached| cached.expires_at.elapsed() < CACHE_TTL)
            .map(|cached| &cached.path)
    }
    
    pub fn set_icon_path(&mut self, icon_name: String, path: PathBuf) {
        self.icon_paths.insert(
            icon_name,
            CachedIconPath {
                path,
                expires_at: Instant::now() + CACHE_TTL,
            },
        );
    }
    
    pub fn index_entry(&mut self, entry: &DesktopEntry) {
        let id = entry.id.to_string();
        
        if let Some(ref wm_class) = entry.startup_wm_class {
            self.wm_class_index.insert(wm_class.to_lowercase(), id.clone());
        }
        
        for wm in &entry.wm_class {
            self.wm_class_index.insert(wm.to_lowercase(), id.clone());
        }
        
        if let Some(ref exec) = entry.exec {
            let exec_base = PathBuf::from(exec)
                .file_stem()
                .and_then(|s| s.to_str())
                .map(|s| s.to_lowercase());
            
            if let Some(exec_base) = exec_base {
                self.exec_index.insert(exec_base, id.clone());
            }
        }
        
        if let Some(ref flatpak_id) = entry.flatpak_id {
            self.flatpak_id_index.insert(flatpak_id.to_lowercase(), id.clone());
        }
        
        if let Some(ref snap_id) = entry.snap_id {
            self.snap_id_index.insert(snap_id.to_lowercase(), id.clone());
        }
    }
    
    pub fn lookup_by_wm_class(&self, wm_class: &str) -> Option<String> {
        self.wm_class_index
            .get(&wm_class.to_lowercase())
            .cloned()
    }
    
    pub fn lookup_by_exec(&self, exec: &str) -> Option<String> {
        let exec_base = PathBuf::from(exec)
            .file_stem()
            .and_then(|s| s.to_str())
            .map(|s| s.to_lowercase());
        
        exec_base.and_then(|e| self.exec_index.get(&e).cloned())
    }
    
    pub fn lookup_by_flatpak_id(&self, flatpak_id: &str) -> Option<String> {
        self.flatpak_id_index
            .get(&flatpak_id.to_lowercase())
            .cloned()
    }
    
    pub fn lookup_by_snap_id(&self, snap_id: &str) -> Option<String> {
        self.snap_id_index
            .get(&snap_id.to_lowercase())
            .cloned()
    }
    
    pub fn get_or_init_theme_cache(&mut self) -> Arc<RwLock<ThemeCache>> {
        if self.theme_cache.is_none() {
            self.theme_cache = Some(Arc::new(RwLock::new(super::theme::build_theme_cache())));
        }
        self.theme_cache.clone().unwrap()
    }
    
    pub fn invalidate_expired(&mut self) {
        let now = Instant::now();
        
        self.desktop_entries.retain(|_, cached| {
            now.duration_since(cached.expires_at) < CACHE_TTL
        });
        
        self.icon_paths.retain(|_, cached| {
            now.duration_since(cached.expires_at) < CACHE_TTL
        });
    }
}

pub struct IconResolver {
    cache: IconCache,
    desktop_paths: Vec<PathBuf>,
}

impl IconResolver {
    pub fn new() -> Self {
        let desktop_paths = get_desktop_search_paths();
        Self {
            cache: IconCache::new(),
            desktop_paths,
        }
    }
    
    pub fn resolve_icon(&mut self, wm_class: Option<&str>, exec: Option<&str>, desktop_id: Option<&str>, flatpak_id: Option<&str>, snap_id: Option<&str>) -> PathBuf {
        if let Some(id) = desktop_id {
            if let Some(entry) = self.find_and_parse_desktop_entry(id) {
                if let Some(ref icon) = entry.icon {
                    if let Some(path) = self.resolve_icon_name(&icon.name) {
                        return path;
                    }
                }
            }
        }
        
        if let Some(id) = flatpak_id.and_then(|fid| self.cache.lookup_by_flatpak_id(fid)) {
            if let Some(entry) = self.find_and_parse_desktop_entry(&id) {
                if let Some(ref icon) = entry.icon {
                    if let Some(path) = self.resolve_icon_name(&icon.name) {
                        return path;
                    }
                }
            }
        }
        
        if let Some(id) = snap_id.and_then(|sid| self.cache.lookup_by_snap_id(sid)) {
            if let Some(entry) = self.find_and_parse_desktop_entry(&id) {
                if let Some(ref icon) = entry.icon {
                    if let Some(path) = self.resolve_icon_name(&icon.name) {
                        return path;
                    }
                }
            }
        }
        
        if let Some(wm) = wm_class {
            if let Some(id) = self.cache.lookup_by_wm_class(wm) {
                if let Some(entry) = self.find_and_parse_desktop_entry(&id) {
                    if let Some(ref icon) = entry.icon {
                        if let Some(path) = self.resolve_icon_name(&icon.name) {
                            return path;
                        }
                    }
                }
            }
        }
        
        if let Some(e) = exec {
            if let Some(id) = self.cache.lookup_by_exec(e) {
                if let Some(entry) = self.find_and_parse_desktop_entry(&id) {
                    if let Some(ref icon) = entry.icon {
                        if let Some(path) = self.resolve_icon_name(&icon.name) {
                            return path;
                        }
                    }
                }
            }
        }
        
        get_fallback_icon("application-x-executable")
    }
    
    fn find_and_parse_desktop_entry(&mut self, desktop_id: &str) -> Option<DesktopEntry> {
        if let Some(entry) = self.cache.get_desktop_entry(desktop_id).cloned() {
            return Some(entry);
        }
        
        let entry = self.scan_for_desktop_entry(desktop_id)?;
        self.cache.set_desktop_entry(entry.clone());
        self.cache.index_entry(&entry);
        
        Some(entry)
    }
    
    fn scan_for_desktop_entry(&self, desktop_id: &str) -> Option<DesktopEntry> {
        let possible_names = vec![
            format!("{}.desktop", desktop_id),
            desktop_id.to_string(),
        ];
        
        for path in &self.desktop_paths {
            for name in &possible_names {
                let full_path = path.join(name);
                if full_path.exists() {
                    return super::desktop::parse_desktop_file(&full_path);
                }
            }
        }
        
        None
    }
    
    fn resolve_icon_name(&mut self, icon_name: &str) -> Option<PathBuf> {
        if let Some(cached) = self.cache.get_icon_path(icon_name).cloned() {
            return Some(cached);
        }
        
        let theme_cache = self.cache.get_or_init_theme_cache();
        let theme = theme_cache.read().unwrap();
        
        let path = super::theme::resolve_icon_path(icon_name, &theme, 16);
        
        if let Some(ref p) = path {
            self.cache.set_icon_path(icon_name.to_string(), p.clone());
        }
        
        path
    }
    
    pub fn scan_desktop_entries(&mut self) -> Vec<DesktopEntry> {
        let mut entries = Vec::new();
        
        for path in &self.desktop_paths {
            if let Ok(dir) = std::fs::read_dir(path) {
                for entry in dir.flatten() {
                    let p = entry.path();
                    if p.extension().map_or(false, |ext| ext == "desktop") {
                        if let Some(desktop) = super::desktop::parse_desktop_file(&p) {
                            self.cache.set_desktop_entry(desktop.clone());
                            self.cache.index_entry(&desktop);
                            entries.push(desktop);
                        }
                    }
                }
            }
        }
        
        entries
    }
    
    pub fn get_all_entries(&mut self) -> Vec<DesktopEntry> {
        self.scan_desktop_entries()
    }
    
    pub fn resolve_icon_path(&mut self, icon_name: &str) -> Option<PathBuf> {
        self.resolve_icon_name(icon_name)
    }
}

fn get_desktop_search_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    
    paths.push(PathBuf::from("/usr/share/applications"));
    
    if let Ok(home) = std::env::var("HOME") {
        paths.push(PathBuf::from(home).join(".local/share/applications"));
    }
    
    paths.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));
    
    if let Ok(home) = std::env::var("HOME") {
        paths.push(PathBuf::from(home).join(".local/share/flatpak/exports/share/applications"));
    }
    
    paths.push(PathBuf::from("/var/lib/snap/applications"));
    
    paths
}

fn get_fallback_icon(name: &str) -> PathBuf {
    let theme_cache = super::theme::build_theme_cache();
    
    let fallback_names = [
        name,
        "application-x-executable",
        "application",
        "unknown",
    ];
    
    for icon_name in &fallback_names {
        if let Some(path) = super::theme::resolve_icon_path(icon_name, &theme_cache, 16) {
            return path;
        }
    }
    
    PathBuf::from("/usr/share/icons/hicolor/128x128/apps/unknown.png")
}