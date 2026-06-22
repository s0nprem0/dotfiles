use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};

fn notify(title: &str, message: &str) {
    let osdctl = helpers_rs::home_dir().join(".config/quickshell/helpers/osdctl");
    if osdctl.exists() {
        let _ = Command::new(&osdctl)
            .args(["show", &format!("{}: {}", title, message), "good", "3000"])
            .status();
    }
    let _ = Command::new("notify-send")
        .args(["-a", "Device Manager", title, message, "-u", "normal"])
        .status();
}

fn main() {
    let mut child = Command::new("udevadm")
        .args(["monitor", "--udev", "--subsystem-match=usb", "--property"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("Failed to start udevadm monitor");

    let stdout = child.stdout.take().expect("Failed to capture stdout");
    let reader = BufReader::new(stdout);

    let mut action = String::new();
    let mut is_mtp = false;
    let mut model = String::new();

    for line in reader.lines() {
        let Ok(line) = line else { continue };

        if line.is_empty() {
            if is_mtp {
                let name = if model.is_empty() {
                    "Your phone".to_string()
                } else {
                    model.replace('_', " ")
                };

                match action.as_str() {
                    "add" => {
                        notify(
                            "Phone Connected",
                            &format!("{} is ready for file transfer.", name),
                        );
                    }
                    "remove" => {
                        notify(
                            "Phone Disconnected",
                            &format!("{} has been disconnected.", name),
                        );
                    }
                    _ => {}
                }
            }

            action.clear();
            is_mtp = false;
            model.clear();
        } else if let Some(val) = line.strip_prefix("ACTION=") {
            action = val.to_string();
        } else if line == "ID_MTP_DEVICE=1" {
            is_mtp = true;
        } else if let Some(val) = line.strip_prefix("ID_MODEL=") {
            model = val.to_string();
        }
    }

    let status = child.wait().expect("Failed to wait on udevadm");
    std::process::exit(status.code().unwrap_or(1));
}
