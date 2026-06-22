# Quickshell Configuration

Hyprland status bar and popups built with Quickshell QML.

## Architecture

```
quickshell/
├── shell.qml                    # Main entry, composes all components
├── bar/                         # Bar modules
│   ├── Bar.qml                  # Base bar component
│   ├── BarModule.qml            # Styled module wrapper
│   ├── Audio.qml                # Volume/media controls
│   ├── Battery.qml              # Battery status
│   ├── Bluetooth.qml            # Bluetooth status
│   ├── Clock.qml                # Time display
│   ├── Network.qml              # Network status
│   └── Workspaces.qml           # Workspace indicator
├── components/                  # Shared QML components
│   ├── DataModule.qml           # Async data loader
│   ├── OsdWindow.qml            # On-screen display
│   └── SlideAnimator.qml        # Animation helper
├── popups/                      # Popup windows
│   ├── PopupPanel.qml           # Base popup container
│   ├── Apps.qml                 # App launcher
│   ├── Battery.qml              # Battery details
│   ├── Media.qml                # Media controls
│   └── ...
├── service/                     # Singleton services
│   ├── Theme.qml                # Color state (matugen integration)
│   ├── Config.qml               # App configuration
│   └── NotificationState.qml    # Notification state
└── scripts/                     # Shell helpers
```

## Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────┐
│   Helper    │────▶│ DataModule  │────▶│ Bar/Popup│
│ (Rust bin)  │     │   (QML)     │     │  (QML)   │
└─────────────┘     └─────────────┘     └──────────┘
       ▲                   │
       │               JSON parse
       │               error handling
       │                   │
  ┌────┴────┐        ┌────▼────┐
  │ matugen │───────▶│ colors  │
  │ (wallp) │        │ .json   │
  └─────────┘        └─────────┘
```

## Key Patterns

- **DataModule**: Wraps external process calls with polling, error handling, and backoff
- **Theme service**: Singleton that manages colors, watches `colors.json` for updates
- **Popup toggle**: Use `qs ipc call shell togglePopup <name>` for keybindings