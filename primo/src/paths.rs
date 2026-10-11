use std::env;
use std::path::PathBuf;

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

/// Where `make install` drops the compiled helper binaries.
pub fn helper_dir() -> PathBuf {
    env::var_os("PRIMO_HELPER_DIR")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/bin/primo")))
        .unwrap_or_else(|| PathBuf::from(".local/bin/primo"))
}

/// Runtime state written by the daemons and helpers (battery history, theme
/// state, app caches). Shared by every binary in the crate, so it must not sit
/// inside any one component's config directory.
pub fn cache_dir() -> PathBuf {
    env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".cache"))
        .join("primo")
}
