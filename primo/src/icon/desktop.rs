use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesktopId {
    pub id: String,
    pub source: DesktopSource,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DesktopSource {
    System,
    Local,
    Flatpak,
    Snap,
}

impl DesktopId {
    pub fn new(id: String, source: DesktopSource) -> Self {
        Self { id, source }
    }

    pub fn from_path(path: &Path) -> Option<Self> {
        let file_name = path.file_name()?.to_str()?;
        let id = file_name.strip_suffix(".desktop")?;
        
        let source = if path.starts_with("/usr/share/applications") {
            DesktopSource::System
        } else if path.starts_with("/var/lib/flatpak") {
            DesktopSource::Flatpak
        } else if path.starts_with("/var/lib/snap") {
            DesktopSource::Snap
        } else {
            DesktopSource::Local
        };
        
        Some(Self { id: id.to_string(), source })
    }

    pub fn to_string(&self) -> String {
        self.id.clone()
    }
}

#[derive(Debug, Clone)]
pub struct IconInfo {
    pub name: String,
    pub is_symbolic: bool,
}

#[derive(Debug, Clone)]
pub struct DesktopEntry {
    pub id: DesktopId,
    pub name: String,
    pub generic_name: Option<String>,
    pub exec: Option<String>,
    pub icon: Option<IconInfo>,
    pub wm_class: Vec<String>,
    pub startup_wm_class: Option<String>,
    pub no_display: bool,
    pub hidden: bool,
    pub only_show_in: Option<String>,
    pub not_show_in: Option<String>,
    pub categories: Vec<String>,
    pub keywords: Vec<String>,
    pub path: PathBuf,
    pub flatpak_id: Option<String>,
    pub snap_id: Option<String>,
}

pub fn parse_desktop_file(path: &Path) -> Option<DesktopEntry> {
    let id = DesktopId::from_path(path)?;
    
    let content = std::fs::read_to_string(path).ok()?;
    
    let mut entry = DesktopEntry {
        id,
        name: String::new(),
        generic_name: None,
        exec: None,
        icon: None,
        wm_class: Vec::new(),
        startup_wm_class: None,
        no_display: false,
        hidden: false,
        only_show_in: None,
        not_show_in: None,
        categories: Vec::new(),
        keywords: Vec::new(),
        path: path.to_path_buf(),
        flatpak_id: None,
        snap_id: None,
    };
    
    let mut in_desktop_entry = false;
    let mut icon_is_symbolic = false;
    
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
                "Name" => entry.name = val.to_string(),
                "GenericName" => entry.generic_name = Some(val.to_string()),
                "Exec" => entry.exec = Some(val.to_string()),
                "Icon" => {
                    if !val.is_empty() {
                        entry.icon = Some(IconInfo {
                            name: val.to_string(),
                            is_symbolic: false,
                        });
                        if val.ends_with(".svg") && val.starts_with("symbolic-") {
                            icon_is_symbolic = true;
                        }
                    }
                }
                "StartupWMClass" => entry.startup_wm_class = Some(val.to_string()),
                "WMClass" => entry.wm_class.push(val.to_string()),
                "NoDisplay" => entry.no_display = val.eq_ignore_ascii_case("true"),
                "Hidden" => entry.hidden = val.eq_ignore_ascii_case("true"),
                "OnlyShowIn" => entry.only_show_in = Some(val.to_string()),
                "NotShowIn" => entry.not_show_in = Some(val.to_string()),
                "Categories" => entry.categories = val.split(';').map(|s| s.to_string()).collect(),
                "Keywords" => entry.keywords = val.split(',').map(|s| s.trim().to_string()).collect(),
                "FlatpakApplicationID" | "ApplicationID" => entry.flatpak_id = Some(val.to_string()),
                "SnapApplicationID" => entry.snap_id = Some(val.to_string()),
                _ => {}
            }
        }
    }
    
    if let Some(icon) = &mut entry.icon {
        icon.is_symbolic = icon_is_symbolic;
    }
    
    if entry.no_display || entry.hidden {
        return None;
    }
    
    Some(entry)
}

pub fn match_desktop_entry(entry: &DesktopEntry, wm_class: &str) -> f32 {
    let mut score = 0.0;
    let wm_lower = wm_class.to_lowercase();
    
    if let Some(ref startup) = entry.startup_wm_class {
        if startup.to_lowercase() == wm_lower {
            score += 100.0;
        } else if startup.to_lowercase().contains(&wm_lower) {
            score += 50.0;
        }
    }
    
    for wm in &entry.wm_class {
        if wm.to_lowercase() == wm_lower {
            score += 80.0;
        } else if wm.to_lowercase().contains(&wm_lower) {
            score += 40.0;
        }
    }
    
    if score > 0.0 {
        score
    } else {
        0.0
    }
}

pub fn match_by_exec(entry: &DesktopEntry, exec: &str) -> f32 {
    if let Some(ref entry_exec) = entry.exec {
        let entry_base = PathBuf::from(entry_exec)
            .file_stem()
            .and_then(|s| s.to_str())
            .map(|s| s.to_lowercase());
        
        let exec_base = PathBuf::from(exec)
            .file_stem()
            .and_then(|s| s.to_str())
            .map(|s| s.to_lowercase());
        
        if let (Some(ref eb), Some(ref ef)) = (entry_base, exec_base) {
            if eb == ef {
                return 100.0;
            }
            if eb.starts_with(ef) || ef.starts_with(eb) {
                return 50.0;
            }
        }
    }
    0.0
}

pub fn find_best_match<'a>(entries: &'a [DesktopEntry], wm_class: &str, exec: Option<&str>) -> Option<&'a DesktopEntry> {
    let mut best: Option<&DesktopEntry> = None;
    let mut best_score = 0.0;
    
    for entry in entries {
        let score = match_desktop_entry(entry, wm_class);
        if score > best_score {
            best = Some(entry);
            best_score = score;
        }
    }
    
    if let Some(exec) = exec {
        for entry in entries {
            let score = match_by_exec(entry, exec);
            if score > best_score {
                best = Some(entry);
                best_score = score;
            }
        }
    }
    
    if best_score > 0.0 {
        best
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_desktop_id_from_path() {
        let path = PathBuf::from("/usr/share/applications/firefox.desktop");
        let id = DesktopId::from_path(&path).unwrap();
        assert_eq!(id.id, "firefox");
    }

    #[test]
    fn test_desktop_id_flatpak_path() {
        let path = PathBuf::from("/var/lib/flatpak/exports/share/applications/com.visualstudio.code.desktop");
        let id = DesktopId::from_path(&path).unwrap();
        assert_eq!(id.id, "com.visualstudio.code");
        assert_eq!(id.source, DesktopSource::Flatpak);
    }

    #[test]
    fn test_match_desktop_entry() {
        let entry = DesktopEntry {
            id: DesktopId::new("test".to_string(), DesktopSource::Local),
            name: "Test".to_string(),
            startup_wm_class: Some("TestApp".to_string()),
            wm_class: vec![],
            icon: None,
            exec: None,
            generic_name: None,
            no_display: false,
            hidden: false,
            only_show_in: None,
            not_show_in: None,
            categories: vec![],
            keywords: vec![],
            path: PathBuf::new(),
            flatpak_id: None,
            snap_id: None,
        };

        let score = match_desktop_entry(&entry, "TestApp");
        assert_eq!(score, 100.0);

        let score = match_desktop_entry(&entry, "testapp");
        assert_eq!(score, 100.0);

        let score = match_desktop_entry(&entry, "OtherApp");
        assert_eq!(score, 0.0);
    }

    #[test]
    fn test_match_by_exec() {
        let entry = DesktopEntry {
            id: DesktopId::new("test".to_string(), DesktopSource::Local),
            name: "Test".to_string(),
            exec: Some("firefox".to_string()),
            startup_wm_class: None,
            wm_class: vec![],
            icon: None,
            generic_name: None,
            no_display: false,
            hidden: false,
            only_show_in: None,
            not_show_in: None,
            categories: vec![],
            keywords: vec![],
            path: PathBuf::new(),
            flatpak_id: None,
            snap_id: None,
        };

        let score = match_by_exec(&entry, "firefox");
        assert_eq!(score, 100.0);

        let score = match_by_exec(&entry, "/usr/bin/firefox");
        assert_eq!(score, 100.0);

        let score = match_by_exec(&entry, "other");
        assert_eq!(score, 0.0);
    }
}