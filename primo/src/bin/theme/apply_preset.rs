use primo::{cache_dir, home_dir, print_json, run_cmd};
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

// Preset files under .config/matugen/presets/ carry name/variant/shell only.
// Hyprland used to have its own colour block here; it was removed with the
// compositor layer, so serde ignores it if an older preset still has one.
#[derive(Default, serde::Deserialize)]
struct PresetJson {
    #[serde(default)]
    name: String,
    #[serde(default)]
    variant: String,
    #[serde(default)]
    shell: ShellColors,
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
    primo::atomic_write_json(&path, &colors).ok();
}

fn run_theme_switcher(home: &PathBuf) {
    // theme_switcher is a repo script, not an installed binary, so locate the
    // checkout rather than assuming it lives at a fixed path.
    let wallpaper_file = home.join(".cache/matugen/current_wallpaper");
    let wallpaper = match fs::read_to_string(&wallpaper_file) {
        Ok(w) => w.trim().to_string(),
        _ => return,
    };
    if wallpaper.is_empty() || !PathBuf::from(&wallpaper).exists() {
        return;
    }

    let candidates = [
        std::env::var_os("DOTFILES").map(PathBuf::from),
        Some(home.join("dotfiles")),
        Some(home.join(".config/dotfiles")),
    ];
    let switcher = candidates
        .into_iter()
        .flatten()
        .map(|root| root.join("scripts/theme_switcher"))
        .find(|p| p.exists());
    let switcher = match switcher {
        Some(p) => p,
        None => return,
    };

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

    let home = home_dir();
    run_theme_switcher(&home);

    print_json(&Status {
        ok: true,
        error: None,
    });
}
