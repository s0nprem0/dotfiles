use helpers_rs::run_cmd;
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Deserialize)]
struct HyprctlActiveWindow {
    at: [i32; 2],
    size: [i32; 2],
}

#[derive(Debug, Clone, Copy)]
enum ScreenshotMode {
    Full,
    Region,
    Active,
    Ocr,
}

struct Screenshot {
    mode: ScreenshotMode,
    save: bool,
    copy: bool,
    path: PathBuf,
    geometry: Option<String>,
}

impl Screenshot {
    fn new(mode: ScreenshotMode, save: bool, copy: bool, geometry: Option<String>) -> Self {
        let dir = screenshot_dir();
        let _ = fs::create_dir_all(&dir);

        let path = dir.join(format!("{}_{}.png", mode.filename(), timestamp(),));

        Self {
            mode,
            save,
            copy,
            path,
            geometry,
        }
    }

    fn capture(&self) -> Option<String> {
    let path_str = self.path.to_string_lossy().to_string();

    let geom_arg = grim_geometry_arg(&self.geometry);

    let qpath = sh_single_quote(&path_str);

    if self.save && self.copy {
        run_cmd(
            "sh",
            &[
                "-c",
                &format!(
                    "grim {} '{}' && wl-copy < '{}'",
                    geom_arg,
                    qpath,
                    qpath
                ),
            ],
        )
    } else if self.save {
        run_cmd(
            "sh",
            &[
                "-c",
                &format!("grim {} '{}'", geom_arg, qpath),
            ],
        )
    } else if self.copy {
        run_cmd(
            "sh",
            &[
                "-c",
                &format!("grim {} - | wl-copy", geom_arg),
            ],
        )
    } else {
        None
    }
}
}

impl ScreenshotMode {
    fn from_str(s: &str) -> Option<Self> {
        match s {
            "full" => Some(Self::Full),
            "region" => Some(Self::Region),
            "active" => Some(Self::Active),
            "ocr" => Some(Self::Ocr),
            _ => None,
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::Full => "Full screen",
            Self::Region => "Region",
            Self::Active => "Active window",
            Self::Ocr => "OCR",
        }
    }

    fn filename(self) -> &'static str {
        match self {
            Self::Full => "full",
            Self::Region => "region",
            Self::Active => "active",
            Self::Ocr => "ocr",
        }
    }
}

fn screenshot_dir() -> PathBuf {
    let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    home.join("Pictures/Screenshots")
}

fn timestamp() -> String {
    run_cmd("date", &["+%Y%m%d_%H%M%S"]).unwrap_or_else(|| "unknown".to_string())
}

fn notify(summary: &str, body: &str) {
    if run_cmd("notify-send", &["-a", "Screenshot", summary, body]).is_none() {
        eprintln!("screenshot: notify-send failed: {summary}");
    }
}

// Escape a string for safe use inside single quotes in a shell command.
// Replaces each ' with '\'' (end quote, escaped quote, reopen quote).
fn sh_single_quote(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 4);
    for ch in s.chars() {
        if ch == '\'' {
            out.push_str("'\\''");
        } else {
            out.push(ch);
        }
    }
    out
}

fn grim_geometry_arg(geometry: &Option<String>) -> String {
    match geometry {
        Some(g) => format!("-g '{}'", sh_single_quote(g)),
        None => String::new(),
    }
}

fn handle_ocr() {
    let region = match run_cmd("slurp", &[]) {
        Some(g) => g,
        None => {
            notify("OCR Cancelled", "No region selected.");
            return;
        }
    };

    let geom_arg = format!("-g '{}'", sh_single_quote(&region));
    let text = match run_cmd(
        "sh",
        &[
            "-c",
            &format!("grim {} - | tesseract stdin stdout", geom_arg),
        ],
    ) {
        Some(t) => t.trim().to_string(),
        None => {
            notify("OCR Failed", "Could not extract text from selection.");
            return;
        }
    };

    if text.is_empty() {
        notify("OCR Result", "No text detected in selection.");
        return;
    }

    let _ = run_cmd("wl-copy", &[&text]);

    let preview = if text.len() > 100 {
        format!("{}...", &text[..100])
    } else {
        text.clone()
    };
    notify("OCR Captured", &preview);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut save = true;
    let mut copy = true;

    let mut arg_idx = 1;
    while arg_idx < args.len() && args[arg_idx].starts_with('-') {
        match args[arg_idx].as_str() {
            "-s" => copy = false,
            "-c" => save = false,
            _ => {
                eprintln!("Usage: screenshot [-s] [-c] [full|region|active|ocr]");
                std::process::exit(1);
            }
        }
        arg_idx += 1;
    }

    let mode = args
        .get(arg_idx)
        .and_then(|s| ScreenshotMode::from_str(s))
        .unwrap_or(ScreenshotMode::Full);

    if matches!(mode, ScreenshotMode::Ocr) {
        handle_ocr();
        return;
    }

    let geometry = match mode {
        ScreenshotMode::Full => None,

        ScreenshotMode::Region => {
            let region = match run_cmd("slurp", &[]) {
                Some(r) => r,
                None => {
                    notify("Screenshot Cancelled", "No region selected.");
                    return;
                }
            };

            Some(region)
        }

        ScreenshotMode::Active => {
            let out = run_cmd("hyprctl", &["-j", "activewindow"]).unwrap_or_default();

            match parse_active_window_geometry(&out) {
                Some(g) => Some(g),
                None => {
                    notify("Screenshot Failed", "Could not get active window info.");
                    return;
                }
            }
        }

        ScreenshotMode::Ocr => unreachable!(),
    };

    let screenshot = Screenshot::new(mode, save, copy, geometry.clone());
    let label = screenshot.mode.label();
    let result = screenshot.capture();

    match result {
        Some(_) => {
            if screenshot.save && screenshot.copy {
                notify(
                    "Screenshot Captured!",
                    &format!("{} saved and copied.", label),
                );
            } else if screenshot.save {
                notify("Screenshot Captured!", &format!("{} saved.", label));
            } else {
                notify(
                    "Screenshot Captured!",
                    &format!("{} copied to clipboard.", label),
                );
            }
        }
        None => notify("Screenshot Failed", "Capture command failed."),
    }
}

fn parse_active_window_geometry(json: &str) -> Option<String> {
    let win: HyprctlActiveWindow = serde_json::from_str(json).ok()?;
    Some(format!(
        "{},{},{}x{}",
        win.at[0], win.at[1], win.size[0], win.size[1]
    ))
}
