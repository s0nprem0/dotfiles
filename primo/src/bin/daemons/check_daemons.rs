use primo::helper_dir;
use std::process::Command;

struct Daemon {
    name: &'static str,
    process_name: &'static str,
    start_command: Box<dyn Fn() -> String>,
}

fn is_running(process_name: &str) -> bool {
    Command::new("pgrep")
        .arg("-f")
        .arg(process_name)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn start(cmd: &str) -> bool {
    Command::new("bash").arg("-c").arg(cmd).spawn().is_ok()
}

fn notify(started: &[String]) {
    if started.is_empty() {
        return;
    }
    let mut lines = Vec::new();
    if !started.is_empty() {
        lines.push(format!("Started: {}", started.join(", ")));
    }
    if Command::new("notify-send")
        .args(["-i", "dialog-information", "-t", "5000", "Daemon Watchdog"])
        .arg(lines.join("\n"))
        .status()
        .map_or(true, |s| !s.success())
    {
        eprintln!("check_daemons: notify-send failed");
    }
}

fn main() {
    // The QuickShell/Hyprland session daemon set is gone, so this now watches
    // only the helpers primo owns itself. Anything added here must have a
    // start command that works without a Wayland session manager.
    let daemons = vec![Daemon {
        name: "Battery Daemon",
        process_name: "battery_daemon",
        start_command: Box::new(|| {
            format!("{}", helper_dir().join("battery_daemon").display())
        }),
    }];

    let mut started = Vec::new();

    for d in &daemons {
        if is_running(d.process_name) {
            continue;
        }
        eprintln!("{} not running, starting...", d.name);
        if start(&(d.start_command)()) {
            started.push(d.name.to_string());
            eprintln!("{} started successfully", d.name);
        } else {
            eprintln!("Failed to start {}", d.name);
        }
    }

    notify(&started);

    if !started.is_empty() {
        println!("Started {} daemon(s)", started.len());
    }
}
