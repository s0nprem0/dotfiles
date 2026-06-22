# Quickshell Rust Helpers

Standalone Rust binaries that provide system data to the Quickshell QML frontend.

## Architecture

```
helpers_rs/
├── Cargo.toml          # Workspace configuration
├── libs/core/          # Shared library (serde helpers, error handling)
└── bins/               # Individual binaries
    ├── get_audio_status      # Audio volume/mute state
    ├── get_battery_status    # Battery level and charging state
    ├── get_bluetooth_status  # Bluetooth adapter status
    ├── get_network_status    # Network connectivity info
    ├── get_power_profile     # Power profile (performance/balanced/power-save)
    ├── osdctl               # OSD control (volume, brightness)
    ├── screenshot           # Screenshot utility
    └── ...
```

## Building

```bash
make all       # Build and install to ../helpers/
make build     # Release build only
make update    # Update Cargo.lock
make format    # Format code
```

## Output Format

All helpers output JSON to stdout. Example:

```json
// get_audio_status
{"default_sink": {"volume": 0.75, "muted": false}}

// get_battery_status
{"capacity": 85, "charging": true}
```

## Integration

Helpers are called by QML `DataModule` components via `Process` and output is parsed as JSON.
Path: `~/.config/quickshell/helpers/<binary_name>`