use std::process::Command;

struct Daemon {
    name: &'static str,
    process_name: &'static str,
    start_command: &'static str,
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
    Command::new("bash")
        .arg("-c")
        .arg(cmd)
        .spawn()
        .is_ok()
}

fn notify(started: &[String], restarted: &[String]) {
    if started.is_empty() && restarted.is_empty() {
        return;
    }
    let mut lines = Vec::new();
    if !started.is_empty() {
        lines.push(format!("Started: {}", started.join(", ")));
    }
    if !restarted.is_empty() {
        lines.push(format!("Restarted: {}", restarted.join(", ")));
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
    let daemons = vec![
        Daemon {
            name: "Quickshell",
            process_name: "quickshell",
            start_command: "uwsm app -- qs",
        },
        Daemon {
            name: "Hyprpaper",
            process_name: "hyprpaper",
            start_command: "uwsm app -- hyprpaper",
        },
        Daemon {
            name: "Battery Daemon",
            process_name: "battery_daemon",
            start_command: "uwsm app -- ~/.config/quickshell/helpers/battery_daemon",
        },
        Daemon {
            name: "Hypridle",
            process_name: "hypridle",
            start_command: "uwsm app -- hypridle",
        },
        Daemon {
            name: "Clipboard (text)",
            process_name: "wl-paste --type text --watch cliphist store",
            start_command: "uwsm app -- ~/.config/hypr/scripts/cliphist.sh store",
        },
        Daemon {
            name: "Clipboard (image)",
            process_name: "wl-paste --type image --watch cliphist store",
            start_command: "uwsm app -- ~/.config/hypr/scripts/cliphist.sh store",
        },
    ];

    let mut started = Vec::new();
    let restarted = Vec::new();

    for d in &daemons {
        if is_running(d.process_name) {
            continue;
        }
        eprintln!("{} not running, starting...", d.name);
        if start(d.start_command) {
            started.push(d.name.to_string());
            eprintln!("{} started successfully", d.name);
        } else {
            eprintln!("Failed to start {}", d.name);
        }
    }

    notify(&started, &restarted);

    if !started.is_empty() {
        println!("Started {} daemon(s)", started.len());
    }
}
