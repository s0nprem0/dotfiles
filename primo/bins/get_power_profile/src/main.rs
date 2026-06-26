use primo::{print_json, run_cmd};
use serde::Serialize;

#[derive(Serialize)]
struct PowerProfileStatus {
    active: String,
    available: Vec<String>,
    driver: String,
}

fn main() {
    let busctl_out = run_cmd(
        "busctl",
        &[
            "get-property",
            "net.hadess.PowerProfiles",
            "/net/hadess/PowerProfiles",
            "net.hadess.PowerProfiles",
            "ActiveProfile",
        ],
    );

    let (active, available, driver) = if let Some(ref out) = busctl_out {
        let active = out
            .trim()
            .strip_prefix("s \"")
            .and_then(|s| s.strip_suffix('"'))
            .unwrap_or("balanced")
            .to_string();
        let profiles_out = run_cmd(
            "busctl",
            &[
                "get-property",
                "net.hadess.PowerProfiles",
                "/net/hadess/PowerProfiles",
                "net.hadess.PowerProfiles",
                "Profiles",
            ],
        );
        let mut available: Vec<String> = Vec::new();
        if let Some(ref pout) = profiles_out {
            for part in pout.split("\"Profile\" s \"").skip(1) {
                if let Some(p) = part.split('"').next() {
                    available.push(p.to_string());
                }
            }
        }
        let driver = if let Some(ref pout) = profiles_out {
            pout.split("\"Driver\" s \"")
                .nth(1)
                .and_then(|s| s.split('"').next())
                .unwrap_or("")
                .to_string()
        } else {
            String::new()
        };
        (active, available, driver)
    } else {
        // Fallback: sysfs
        let raw =
            std::fs::read_to_string("/sys/firmware/acpi/platform_profile").unwrap_or_default();
        let active = match raw.trim() {
            "quiet" => "power-saver",
            other => other,
        }
        .to_string();
        let available = std::fs::read_to_string("/sys/firmware/acpi/platform_profile_choices")
            .map(|c| {
                c.split_whitespace()
                    .map(|s| {
                        match s {
                            "quiet" => "power-saver",
                            o => o,
                        }
                        .to_string()
                    })
                    .collect()
            })
            .unwrap_or_else(|_| {
                vec![
                    "power-saver".into(),
                    "balanced".into(),
                    "performance".into(),
                ]
            });
        (active, available, "platform_profile".to_string())
    };

    print_json(&PowerProfileStatus {
        active,
        available,
        driver,
    });
}
