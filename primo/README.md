# primo

Standalone Rust binaries that read system state and perform system actions.

They print JSON on stdout, so any shell script, status bar, or launcher can
consume them without linking against anything.

> These were originally written to feed a Quickshell QML frontend that no longer
> ships with this repo. The binaries are kept and still build, but nothing in
> the repo calls them automatically — invoke them by path, or delete the ones
> you do not need.

## Architecture

```
primo/
├── Cargo.toml          # Workspace configuration
├── src/
│   ├── lib.rs          # Shared library (serde helpers, paths, process helpers)
│   └── bin/            # Individual binaries
│       ├── status/     # State readers, called on demand
│       ├── daemons/    # Long-running background processes
│       ├── utils/      # Invoked on demand (osdctl, screenshot, caffeine)
│       ├── icon/       # Icon resolution
│       └── theme/      # Theme presets
```

Current binaries:

| Binary | Purpose |
|---|---|
| `get_battery_status` | Battery level, charging state, health |
| `get_bluetooth_status` | Adapter state and connected devices |
| `get_power_profile` | Power profile (power-save / balanced / performance) |
| `get_sysmon_status` | CPU, memory, disk, network throughput |
| `get_sys_diagnostics` | System diagnostics for the settings popup |
| `get_apps_list` | App launcher, backed by SQLite |
| `osdctl` | OSD control (volume, brightness, microphone) |
| `screenshot` | Screenshot utility |
| `caffeine` | `systemd-inhibit` wrapper for idle inhibition |
| `ports_menu` | Listening ports |
| `parse_binds` | Parses Hyprland keybindings for the shortcuts popup |
| `battery_daemon`, `log_battery`, `check_daemons`, `mtp_notify` | Background daemons |
| `list_presets`, `apply_preset` | Theme preset management |

## Building

```bash
make all       # Build and install to ~/.local/bin/primo/
make build     # Release build only
make update    # Update Cargo.lock
make format    # Format code
```

Set `PRIMO_HELPER_DIR` to install somewhere else.

## Output Format

Status helpers output JSON to stdout. Example:

```json
// get_battery_status
{"capacity": 85, "charging": true, "status": "Charging"}
```

Action helpers (`osdctl`, `screenshot`, `caffeine`) may print plain text or
nothing; their effect is usually observed through the state file they write
(`~/.cache/primo/`) or through a device change.

## Integration

Invoke a helper by path and parse the JSON:

```bash
~/.local/bin/primo/get_battery_status | jq .capacity
```

`get_apps_list` reads an on-disk SQLite index built incrementally; the first
call after a change to the desktop database pays a full scan.

When adding a helper, prefer the cheapest option that still updates: a native
binding that reacts to a signal costs no subprocesses, where a helper polled
every 30s costs about 2,880 forks a day.