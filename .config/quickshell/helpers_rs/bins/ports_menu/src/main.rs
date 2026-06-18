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

    let input = entries
        .iter()
        .map(|e| e.label.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    let mut fzf = match Command::new("fzf")
        .args(["--prompt=Ports > ", "--height=60%", "--layout=reverse"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(c) => c,
        Err(_) => return,
    };

    if let Some(mut stdin) = fzf.stdin.take() {
        use std::io::Write;
        let _ = stdin.write_all(input.as_bytes());
    }

    let selected = match fzf.wait_with_output() {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).trim().to_string(),
        _ => return,
    };

    let pid = entries.iter().find(|e| e.label == selected).map(|e| e.pid);

    let Some(pid) = pid else {
        return;
    };

    let _ = Command::new("kill")
        .args(["-15", &pid.to_string()])
        .status();

    std::thread::sleep(std::time::Duration::from_secs(2));

    let _ = Command::new("kill").args(["-9", &pid.to_string()]).status();

    let _ = Command::new("notify-send")
        .args(["Ports", &format!("Killed process {}", pid)])
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

        if parts.len() < 6 {
            continue;
        }

        let proto = parts[0];
        let local = parts[4];

        let process = parts
            .iter()
            .find(|s| s.contains("pid="))
            .copied()
            .unwrap_or("");

        let pid = extract_pid(process);
        let pname = extract_name(process);

        let Some(pid) = pid else {
            continue;
        };

        let (ip, port) = parse_local_addr(local);

        let icon = match proto {
            "tcp" | "tcp6" => "",
            "udp" | "udp6" => "",
            _ => "",
        };

        entries.push(PortEntry {
            label: format!("{} {:<6} {:<20} {:<5} {}", icon, port, pname, proto, ip),
            pid,
        });
    }

    entries
}

fn parse_local_addr(addr: &str) -> (&str, &str) {
    if let Some(rest) = addr.strip_prefix('[') {
        if let Some(pos) = rest.find("]:") {
            let ip = &rest[..pos];
            let port = &rest[pos + 2..];
            return (ip, port);
        }
    }

    if let Some(pos) = addr.rfind(':') {
        let ip = &addr[..pos];
        let port = &addr[pos + 1..];
        return (ip, port);
    }

    (addr, "")
}

fn extract_pid(s: &str) -> Option<u32> {
    let start = s.find("pid=")?;
    let rest = &s[start + 4..];

    let end = rest
        .find(|c: char| !c.is_ascii_digit())
        .unwrap_or(rest.len());

    rest[..end].parse().ok()
}

fn extract_name(s: &str) -> String {
    let start = match s.find('"') {
        Some(i) => i + 1,
        None => return String::new(),
    };

    let rest = &s[start..];

    match rest.find('"') {
        Some(end) => rest[..end].to_string(),
        None => String::new(),
    }
}
