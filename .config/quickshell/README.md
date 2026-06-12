# Quickshell Configuration

Configuration for Quickshell (Hyprland status bar and OSD).

## Components

### OSD (`components/OsdWindow.qml`)
On-screen display for volume, brightness, and other system feedback. Contains utility functions:
- `getPercentage(msg)` - Extract numeric percentage from message
- `getPrefix(msg)` - Extract label prefix
- `getPercentText(msg)` - Extract percentage text
- `getIcon(msg)` - Return icon based on message type
- `getIconColor(msg)` - Return color based on message type

### Bar Components (`bar/`)
Status bar modules using `BarModule.qml` as base:
- `Audio.qml` - Volume and media controls
- `Battery.qml` - Battery status
- `Network.qml` - Network status
- `Bluetooth.qml` - Bluetooth status
- `Tray.qml` - System tray
- `Workspaces.qml` - Hyprland workspaces