use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct IconTheme {
    pub name: String,
    pub directories: Vec<IconDirectory>,
    pub parent: Option<String>,
    pub hidden: bool,
}

#[derive(Debug, Clone)]
pub struct IconDirectory {
    pub path: PathBuf,
    pub context: String,
    pub size: IconSize,
    pub type_: IconType,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IconSize {
    Pixel(u32),
    Scalable,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IconType {
    Fixed,
    Scalable,
    Symbolic,
}

#[derive(Debug, Clone)]
pub struct ThemeCache {
    pub current_theme: IconTheme,
    pub inherited_themes: Vec<IconTheme>,
    pub hicolor: IconTheme,
    pub icon_paths: HashMap<String, PathBuf>,
    pub symbolic_paths: HashMap<String, PathBuf>,
}

pub fn load_theme(theme_name: &str, theme_paths: &[PathBuf]) -> Option<IconTheme> {
    for theme_path in theme_paths {
        let theme_dir = theme_path.join(theme_name);
        if let Some(theme) = parse_theme_directory(&theme_dir) {
            return Some(theme);
        }
    }
    None
}

fn parse_theme_directory(theme_dir: &Path) -> Option<IconTheme> {
    let index_path = theme_dir.join("index.theme");
    if !index_path.exists() {
        return None;
    }
    
    let content = std::fs::read_to_string(&index_path).ok()?;
    
    let mut theme = IconTheme {
        name: theme_dir.file_name()?.to_string_lossy().to_string(),
        directories: Vec::new(),
        parent: None,
        hidden: false,
    };
    
    let mut in_icon_context = false;
    
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        
        if line.starts_with('[') && line.ends_with(']') {
            in_icon_context = line.contains("Icon Theme");
            continue;
        }
        
        if !in_icon_context {
            continue;
        }
        
        if let Some(pos) = line.find('=') {
            let key = line[..pos].trim();
            let val = line[pos + 1..].trim();
            
            match key {
                "Inherits" => theme.parent = Some(val.to_string()),
                "Hidden" => theme.hidden = val.eq_ignore_ascii_case("true"),
                "Context" => {
                    let size_match: Vec<&str> = val.split(' ').collect();
                    let size = if size_match.len() > 0 {
                        size_match[0]
                    } else {
                        "64"
                    };
                    
                    let type_ = if val.contains("scalable") {
                        IconType::Scalable
                    } else if val.contains("symbolic") {
                        IconType::Symbolic
                    } else {
                        IconType::Fixed
                    };
                    
                    let _size_val = size.parse::<u32>().ok();
                    
                    theme.directories.push(IconDirectory {
                        path: theme_dir.join(&size_match.get(1).unwrap_or(&"").to_string()),
                        context: val.to_string(),
                        size: IconSize::Scalable,
                        type_,
                    });
                }
                "Size" => {}
                _ => {}
            }
        }
    }
    
    parse_icon_directories(theme_dir, &mut theme);
    
    Some(theme)
}

fn parse_icon_directories(theme_dir: &Path, theme: &mut IconTheme) {
    let sizes = [
        ("16x16", IconSize::Pixel(16)),
        ("22x22", IconSize::Pixel(22)),
        ("24x24", IconSize::Pixel(24)),
        ("32x32", IconSize::Pixel(32)),
        ("36x36", IconSize::Pixel(36)),
        ("48x48", IconSize::Pixel(48)),
        ("64x64", IconSize::Pixel(64)),
        ("72x72", IconSize::Pixel(72)),
        ("96x96", IconSize::Pixel(96)),
        ("128x128", IconSize::Pixel(128)),
        ("256x256", IconSize::Pixel(256)),
        ("scalable", IconSize::Scalable),
    ];
    
    for (dir_name, size) in &sizes {
        let dir_path = theme_dir.join(dir_name);
        if dir_path.exists() {
            theme.directories.push(IconDirectory {
                path: dir_path,
                context: dir_name.to_string(),
                size: *size,
                type_: IconType::Fixed,
            });
        }
    }
    
    let scalable_path = theme_dir.join("scalable");
    if scalable_path.exists() {
        if let Ok(entries) = std::fs::read_dir(&scalable_path) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().map_or(false, |ext| ext == "svg") {
                    theme.directories.push(IconDirectory {
                        path: scalable_path.clone(),
                        context: "scalable".to_string(),
                        size: IconSize::Scalable,
                        type_: IconType::Scalable,
                    });
                    break;
                }
            }
        }
    }
    
    let symbolic_path = theme_dir.join("symbolic");
    if symbolic_path.exists() {
        theme.directories.push(IconDirectory {
            path: symbolic_path,
            context: "symbolic".to_string(),
            size: IconSize::Scalable,
            type_: IconType::Symbolic,
        });
    }
}

pub fn resolve_icon_path(
    icon_name: &str,
    theme_cache: &ThemeCache,
    size: u32,
) -> Option<PathBuf> {
    let mut search_order: Vec<&IconTheme> = Vec::new();
    
    search_order.push(&theme_cache.current_theme);
    
    for theme in &theme_cache.inherited_themes {
        search_order.push(theme);
    }
    
    search_order.push(&theme_cache.hicolor);
    
    for theme in &search_order {
        if let Some(path) = find_icon_in_theme(icon_name, theme, size) {
            return Some(path);
        }
    }
    
    None
}

fn find_icon_in_theme(icon_name: &str, theme: &IconTheme, size: u32) -> Option<PathBuf> {
    for dir in &theme.directories {
        let path = match dir.size {
            IconSize::Pixel(target_size) => {
                if target_size >= size {
                    dir.path.join(icon_name)
                } else {
                    continue;
                }
            }
            IconSize::Scalable => {
                dir.path.join(icon_name)
            }
        };
        
        if path.exists() {
            return Some(path);
        }
    }
    
    if icon_name.ends_with(".png") || icon_name.ends_with(".svg") {
        for dir in &theme.directories {
            let path = dir.path.join(icon_name);
            if path.exists() {
                return Some(path);
            }
        }
    }
    
    None
}

pub fn get_icon_paths_for_name(icon_name: &str, theme: &IconTheme) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    
    for dir in &theme.directories {
        let path = dir.path.join(icon_name);
        if path.exists() {
            paths.push(path);
        }
    }
    
    paths
}

pub fn build_theme_cache() -> ThemeCache {
    let theme_paths = get_theme_search_paths();
    
    let current_theme = load_theme("macOS", &theme_paths)
        .or_else(|| load_theme("Adwaita", &theme_paths))
        .unwrap_or_else(|| create_default_theme());
    
    let inherited_themes: Vec<IconTheme> = if let Some(ref parent) = current_theme.parent {
        parent.split(',')
            .filter_map(|name| load_theme(name.trim(), &theme_paths))
            .collect()
    } else {
        Vec::new()
    };
    
    let hicolor = load_theme("hicolor", &theme_paths).unwrap_or_else(|| create_default_theme());
    
    ThemeCache {
        current_theme,
        inherited_themes,
        hicolor,
        icon_paths: HashMap::new(),
        symbolic_paths: HashMap::new(),
    }
}

fn get_theme_search_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    
    if let Ok(xdg_data_home) = std::env::var("XDG_DATA_HOME") {
        paths.push(PathBuf::from(xdg_data_home));
    } else if let Ok(home) = std::env::var("HOME") {
        paths.push(PathBuf::from(home).join(".local/share/icons"));
    }
    
    paths.push(PathBuf::from("/usr/share/icons"));
    
    if let Ok(xdg_data_dirs) = std::env::var("XDG_DATA_DIRS") {
        for dir in xdg_data_dirs.split(':') {
            if !dir.is_empty() {
                paths.push(PathBuf::from(dir).join("icons"));
            }
        }
    }
    
    paths
}

fn create_default_theme() -> IconTheme {
    IconTheme {
        name: "hicolor".to_string(),
        directories: Vec::new(),
        parent: None,
        hidden: false,
    }
}