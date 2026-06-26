use std::collections::{HashMap, HashSet};
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};

fn notify(title: &str, message: &str) {
    let _ = Command::new("notify-send")
        .args(["-a", "Device Manager", title, message, "-u", "normal"])
        .status();
}

fn main() {
    let mut child = match Command::new("udevadm")
        .args([
            "monitor",
            "--udev",
            "--subsystem-match=usb",
            "--property",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("mtp_notify: failed to start udevadm monitor: {e}");
            eprintln!("mtp_notify: is udevadm installed and in PATH?");
            std::process::exit(1);
        }
    };

    let Some(stdout) = child.stdout.take() else {
        eprintln!("mtp_notify: failed to capture stdout");
        std::process::exit(1);
    };
    let reader = BufReader::new(stdout);

    let mut props = HashMap::<String, String>::new();
    let mut connected = HashSet::<String>::new();

    for line in reader.lines() {
        let Ok(line) = line else {
            continue;
        };

        if line.is_empty() {
            let action = props.get("ACTION").map(String::as_str);

            let is_usb_device = matches!(
                props.get("DEVTYPE").map(String::as_str),
                Some("usb_device")
            );

            let is_mtp = props.contains_key("ID_MTP_DEVICE")
                || props.contains_key("ID_MEDIA_PLAYER");

            if is_usb_device && is_mtp {
                let device_id = props
                    .get("ID_SERIAL")
                    .or_else(|| props.get("ID_SERIAL_SHORT"))
                    .or_else(|| props.get("DEVPATH"))
                    .cloned()
                    .unwrap_or_else(|| "unknown".to_string());

                let vendor = props
                    .get("ID_VENDOR_FROM_DATABASE")
                    .or_else(|| props.get("ID_VENDOR"))
                    .map(String::as_str)
                    .unwrap_or("");

                let model = props
                    .get("ID_MODEL_FROM_DATABASE")
                    .or_else(|| props.get("ID_MODEL"))
                    .map(String::as_str)
                    .unwrap_or("Phone");

                let name = if vendor.is_empty() {
                    model.replace('_', " ")
                } else {
                    format!("{} {}", vendor, model.replace('_', " "))
                };

                match action {
                    Some("add") => {
                        if connected.insert(device_id.clone()) {
                            notify(
                                "Phone Connected",
                                &format!("{name} is ready for file transfer."),
                            );
                        }
                    }

                    Some("remove") => {
                        if connected.remove(&device_id) {
                            notify(
                                "Phone Disconnected",
                                &format!("{name} has been disconnected."),
                            );
                        }
                    }

                    _ => {}
                }
            }

            props.clear();
            continue;
        }

        if let Some((key, value)) = line.split_once('=') {
            props.insert(key.to_owned(), value.to_owned());
        }
    }

    let status = child.wait().expect("Failed to wait on udevadm");
    std::process::exit(status.code().unwrap_or(1));
}
