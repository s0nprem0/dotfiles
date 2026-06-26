use primo::{DisplayMode, get_monitors, set_mode_verified, toggle_mode};

fn main() {
    let args: Vec<String> = std::env::args().collect();
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
            toggle_mode();
            return;
        }
        _ => Err(format!("Unknown action: {}", command)),
    };

    match action {
        Ok(mode) => {
            let monitors = get_monitors();
            match set_mode_verified(mode, &monitors) {
                Ok(()) => {}
                Err(e) => {
                    eprintln!("{}", e);
                    std::process::exit(1);
                }
            }
        }
        Err(e) => {
            eprintln!("{}", e);
            std::process::exit(1);
        }
    }
}