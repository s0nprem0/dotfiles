use std::env;
use primo::{DisplayMode, get_current_mode, get_monitors, set_mode, toggle_mode};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: display_toggle {{extend|duplicate|external|internal|toggle}}");
        std::process::exit(1);
    }

    let command = args[1].as_str();
    let action = match command {
        "extend" => Ok(DisplayMode::Extend),
        "duplicate" => Ok(DisplayMode::Duplicate),
        "external" => Ok(DisplayMode::External),
        "internal" => Ok(DisplayMode::Internal),
        "toggle" => {
            let monitors = get_monitors();
            toggle_mode();
            return;
        }
        _ => Err(format!("Unknown action: {}", command)),
    };

    match action {
        Ok(mode) => {
            let monitors = get_monitors();
            set_mode(mode, &monitors);
        }
        Err(e) => {
            eprintln!("{}", e);
            std::process::exit(1);
        }
    }
}