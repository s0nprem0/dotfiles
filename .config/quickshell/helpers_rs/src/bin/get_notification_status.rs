use helpers_rs::print_json;
use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
struct Notification {
    id: String,
    summary: String,
    body: String,
    app_name: String,
    urgency: u8,
    icon: String,
}

#[derive(Serialize)]
struct NotifStatus {
    activeNotifs: Vec<Notification>,
    historyNotifs: Vec<Notification>,
}

fn main() {
    // Fetch active notifications from swaync
    let active_notifs = get_notifications("--get-notifications");
    let history_notifs = get_notifications("--get-history");

    let status = NotifStatus {
        activeNotifs: active_notifs,
        historyNotifs: history_notifs,
    };
    print_json(&status);
}

fn get_notifications(arg: &str) -> Vec<Notification> {
    let mut notifs = Vec::new();
    if let Ok(output) = Command::new("swaync-client").arg(arg).output() {
        if output.status.success() {
            if let Ok(stdout) = String::from_utf8(output.stdout) {
                // Parse swaync's JSON output (you'll need to adapt based on actual format)
                // This is a placeholder – adjust to match swaync's actual output structure
                if let Ok(json) = serde_json::from_str::<Vec<serde_json::Value>>(&stdout) {
                    for item in json {
                        notifs.push(Notification {
                            id: item["id"].as_str().unwrap_or("").to_string(),
                            summary: item["summary"].as_str().unwrap_or("").to_string(),
                            body: item["body"].as_str().unwrap_or("").to_string(),
                            app_name: item["app_name"].as_str().unwrap_or("").to_string(),
                            urgency: item["urgency"].as_u64().unwrap_or(1) as u8,
                            icon: item["icon"].as_str().unwrap_or("").to_string(),
                        });
                    }
                }
            }
        }
    }
    notifs
}