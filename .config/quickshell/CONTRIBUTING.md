# Contributing to Quickshell Dotfiles

## Development Setup

### Dependencies

**Required:**
- `quickshell` (0.3+) - Wayland shell framework
- `hyprland` - Wayland compositor

**Audio:**
- `playerctl` - Media player control
- `pactl` / `wpctl` - PulseAudio/WirePlumber control

**System:**
- `brightnessctl` - Screen brightness control
- `upower` - Battery information
- `networkmanager` / `nmcli` - Network status
- `bluez` / `bluetoothctl` - Bluetooth control

**Helpers (Rust):**
- Rust toolchain
- `cargo` - Build system

### Building Rust Helpers

```bash
cd helpers_rs
make all  # Build and install to ../helpers/
```

## Architecture

```
quickshell/
├── shell.qml              # Entry point
├── bar/                   # Bar modules
├── components/            # Shared QML components
├── popups/                # Popup windows
├── service/               # Singleton services
└── helpers/               # Shell helper scripts
```

## Adding New Components

1. Create component in `components/`
2. Export from `qmldir` if needed
3. Import and use in parent component

## Adding New Bar Modules

1. Create QML file in `bar/`
2. Add to `shell.qml` under appropriate section
3. Follow existing patterns (BarModule wrapper)

## Debugging

- QML console output goes to stdout
- Use `console.log()` for debugging
- Check quickshell logs: `journalctl --user -u quickshell`

## Code Style

- 4-space indentation
- Brutalist aesthetic: minimal rounded corners, sharp borders
- Primary color (#ffb4a7) for accents
- Consistent icon usage from Nerd Fonts