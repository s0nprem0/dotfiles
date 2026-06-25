use helpers_rs::{cache_dir, home_dir, print_json, run_cmd};
use serde::Serialize;
use std::fs;
use std::path::PathBuf;

#[derive(Default, serde::Deserialize)]
struct ShellColors {
    #[serde(default)]
    bg: String,
    #[serde(default)]
    fg: String,
    #[serde(default)]
    surface: String,
    #[serde(default)]
    surfaceLighter: String,
    #[serde(default)]
    primary: String,
    #[serde(default)]
    muted: String,
    #[serde(default)]
    error: String,
    #[serde(default)]
    warning: String,
    #[serde(default)]
    green: String,
    #[serde(default)]
    blue: String,
}

#[derive(Default, serde::Deserialize)]
struct HyprlandColors {
    #[serde(default)]
    accent: String,
    #[serde(default)]
    surface: String,
    #[serde(default)]
    on_surface: String,
    #[serde(default)]
    error_hex: String,
}

#[derive(Default, serde::Deserialize)]
struct PresetJson {
    #[serde(default)]
    name: String,
    #[serde(default)]
    variant: String,
    #[serde(default)]
    shell: ShellColors,
    #[serde(default)]
    hyprland: HyprlandColors,
}

#[derive(Serialize)]
struct ColorsJson {
    bg: String,
    fg: String,
    surface: String,
    surfaceLighter: String,
    primary: String,
    muted: String,
    error: String,
    warning: String,
    green: String,
    blue: String,
}

#[derive(Serialize)]
struct Status {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn write_colors_json(cache: &PathBuf, s: &ShellColors) {
    let path = cache.join("colors.json");
    let colors = ColorsJson {
        bg: s.bg.clone(),
        fg: s.fg.clone(),
        surface: s.surface.clone(),
        surfaceLighter: s.surfaceLighter.clone(),
        primary: s.primary.clone(),
        muted: s.muted.clone(),
        error: s.error.clone(),
        warning: s.warning.clone(),
        green: s.green.clone(),
        blue: s.blue.clone(),
    };
    helpers_rs::atomic_write_json(&path, &colors).ok();
}

fn write_colors_qml(cache: &PathBuf, s: &ShellColors) {
    let path = cache.join("Colors.qml");
    let qml = format!(
        r#"pragma Singleton
QtObject {{
    property color bg: "{}"
    property color fg: "{}"
    property color surface: "{}"
    property color surfaceLighter: "{}"
    property color primary: "{}"
    property color muted: "{}"
    property color error: "{}"
    property color warning: "{}"
    property color green: "{}"
    property color blue: "{}"
    property color tertiary: "{}"
}}
"#,
        s.bg, s.fg, s.surface, s.surfaceLighter, s.primary,
        s.muted, s.error, s.warning, s.green, s.blue, s.surfaceLighter
    );
    fs::write(&path, &qml).ok();
}

fn write_hyprland_colors(h: &HyprlandColors, home: &PathBuf) {
    let colors_lua = home.join(".config/hypr/colors.lua");
    let colors_lock = home.join(".config/hypr/colors-hyprlock.conf");

    if h.accent.is_empty() {
        return;
    }

    // Only write if the target files exist
    if colors_lua.exists() {
        let lua = format!(
            r#"return {{
  accent = "{}",
  surface = "{}",
  on_surface = "{}",
  error_hex = "{}",
}}
"#,
            h.accent, h.surface, h.on_surface, h.error_hex
        );
        fs::write(&colors_lua, &lua).ok();
    }

    if colors_lock.exists() {
        let lock = format!(
            r#"\$accent = rgb({})
\$surface = rgb({})
\$on_surface = rgb({})
"#,
            h.accent, h.surface, h.on_surface
        );
        fs::write(&colors_lock, &lock).ok();
    }
}

fn run_theme_switcher(home: &PathBuf) {
    let cache = cache_dir();
    let wallpaper_file = cache.join("current_wallpaper");
    let wallpaper = match fs::read_to_string(&wallpaper_file) {
        Ok(w) => w.trim().to_string(),
        _ => return,
    };
    if wallpaper.is_empty() || !PathBuf::from(&wallpaper).exists() {
        return;
    }

    let switcher = home.join("dotfiles/scripts/theme_switcher");
    if !switcher.exists() {
        return;
    }

    run_cmd(
        &switcher.to_string_lossy(),
        &[
            "--apps",
            "kitty,gtk3,gtk4,vesktop,thunar,spicetify,zathura,bat,btop,eza,fastfetch",
            &wallpaper,
        ],
    );
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        print_json(&Status {
            ok: false,
            error: Some("Usage: apply_preset <preset_file>".into()),
        });
        std::process::exit(1);
    }

    let preset_path = PathBuf::from(&args[1]);
    let content = match fs::read_to_string(&preset_path) {
        Ok(c) => c,
        Err(e) => {
            print_json(&Status {
                ok: false,
                error: Some(format!("Failed to read preset: {e}")),
            });
            std::process::exit(1);
        }
    };

    let preset: PresetJson = match serde_json::from_str(&content) {
        Ok(p) => p,
        Err(e) => {
            print_json(&Status {
                ok: false,
                error: Some(format!("Failed to parse preset: {e}")),
            });
            std::process::exit(1);
        }
    };

    let cache = cache_dir();
    fs::create_dir_all(&cache).ok();

    write_colors_json(&cache, &preset.shell);
    write_colors_qml(&cache, &preset.shell);

    let home = home_dir();
    write_hyprland_colors(&preset.hyprland, &home);
    run_theme_switcher(&home);

    print_json(&Status {
        ok: true,
        error: None,
    });
}
