use std::process::Command;
use std::str;

pub fn run_cmd(cmd: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    str::from_utf8(&output.stdout)
        .ok()
        .map(|s| s.trim().to_string())
}

pub fn run_cmd_with_stderr(cmd: &str, args: &[&str]) -> Option<(String, String)> {
    let output = Command::new(cmd).args(args).output().ok()?;
    let stdout = str::from_utf8(&output.stdout).ok()?.trim().to_string();
    let stderr = str::from_utf8(&output.stderr).ok()?.trim().to_string();
    Some((stdout, stderr))
}
