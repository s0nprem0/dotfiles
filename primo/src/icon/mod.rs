pub mod cache;
pub mod desktop;
pub mod theme;

pub use cache::IconCache;
pub use desktop::{DesktopEntry, DesktopId, IconInfo, parse_desktop_file};
pub use theme::{IconTheme, ThemeCache, resolve_icon_path};

use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct ApplicationInfo {
    pub desktop_id: String,
    pub name: String,
    pub icon_name: String,
    pub exec: String,
    pub wm_class: Option<String>,
    pub startup_wm_class: Option<String>,
    pub icon_path: Option<PathBuf>,
}

#[derive(Debug, Clone)]
pub struct IconResult {
    pub icon_path: PathBuf,
    pub icon_name: String,
    pub theme: String,
    pub is_cached: bool,
}

impl IconResult {
    pub fn to_qml_source(&self) -> String {
        if self.icon_path.exists() {
            format!("file://{}", self.icon_path.display())
        } else {
            format!("image://icon/{}", self.icon_name)
        }
    }
}