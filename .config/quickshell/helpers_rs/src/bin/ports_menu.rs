use std::io::Write;
use std::process::{Command, Stdio};

struct PortEntry {
    label: String,
    pid: u32,
}

fn main() {
    let entries = parse_ss();
    if entries.is_empty() {
        let _ = Command::new("notify-send")
            .args(["Ports", "No listening ports found"])
            .status();
        return;
    }

    let mut input = String::new();
    for e in &entries {
        input.push_str(&e.label);
        input.push('\n');
    }

    let home = std::env::var("HOME").unwrap_or_default();
    let theme = format!("{}/.config/rofi/ports.rasi", home);

    let mut child = match Command::new("rofi")
        .args([
            "-dmenu",
            "-p",
            "Ports",
            "-format",
            "i",
            "-mesg",
            "Select a port to kill the process",
            "-theme",
            &theme,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(c) => c,
        Err(_) => return,
    };

    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(input.as_bytes());
        drop(stdin);
    }

    let output = match child.wait_with_output() {
        Ok(o) => o,
        Err(_) => return,
    };

    let index: usize = match String::from_utf8_lossy(&output.stdout).trim().parse() {
        Ok(i) => i,
        Err(_) => return,
    };

    if index >= entries.len() {
        return;
    }

    let pid = entries[index].pid;
    // Try graceful SIGTERM first, escalate to SIGKILL after 3s
    let _ = Command::new("kill").args(["-15", &pid.to_string()]).status();
    std::thread::sleep(std::time::Duration::from_secs(3));
    let _ = Command::new("kill").args(["-9", &pid.to_string()]).status();
    let _ = Command::new("notify-send")
        .args(["Ports", &format!("Killed process with PID {}", pid)])
        .status();
}

fn parse_ss() -> Vec<PortEntry> {
    let output = match Command::new("ss").args(["-tulpn"]).output() {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return Vec::new(),
    };

    let mut entries = Vec::new();
    for line in output.lines().skip(1) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 7 {
            continue;
        }

        let proto = parts[0];
        let local = parts[4];
        let process = parts[6];

        let (ip, port) = parse_local_addr(local);
        let pid = extract_pid(process);
        let pname = extract_name(process);

        let Some(pid) = pid else { continue };

        let icon = match proto {
            "tcp" | "tcp6" => "\u{f817}",
            "udp" | "udp6" => "\u{f818}",
            _ => "\u{f0c9}",
        };

        entries.push(PortEntry {
            label: format!("{}  {}  {}  ({} {})", icon, port, pname, proto, ip),
            pid,
        });
    }
    entries
}

fn parse_local_addr(addr: &str) -> (&str, &str) {
    if let Some(rest) = addr.strip_prefix('[') {
        // IPv6: [::1]:5353
        if let Some(pos) = rest.find("]:") {
            let ip = &rest[..pos];
            let port = &rest[pos + 2..];
            return (ip, port);
        }
    }
    // IPv4 or hostname: 0.0.0.0:22
    if let Some(pos) = addr.rfind(':') {
        let ip = &addr[..pos];
        let port = &addr[pos + 1..];
        return (ip, port);
    }
    (addr, "")
}

fn extract_pid(s: &str) -> Option<u32> {
    let s = if s.starts_with("users:") { &s[6..] } else { s };
    if let Some(start) = s.find("pid=") {
        let rest = &s[start + 4..];
        let end = rest.find(|c: char| !c.is_ascii_digit()).unwrap_or(rest.len());
        rest[..end].parse().ok()
    } else {
        None
    }
}

fn extract_name(s: &str) -> String {
    let s = if s.starts_with("users:") { &s[6..] } else { s };
    if let Some(start) = s.find('"') {
        let rest = &s[start + 1..];
        if let Some(end) = rest.find('"') {
            return rest[..end].to_string();
        }
    }
    String::new()
}
