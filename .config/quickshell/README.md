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
│   ├── SlideAnimator.qml        # Animation helper
│   ├── VolumeSlider.qml         # Reusable volume/slider control
│   ├── MuteButton.qml           # Mute toggle button
│   └── DeviceSelector.qml       # Audio device selector dropdown
├── popups/                      # Popup windows
│   ├── PopupPanel.qml           # Base popup container
│   ├── Apps.qml                 # App launcher (5-tab)
│   │   └── apps/                # Apps popup components
│   │       ├── AppsTab.qml      # Applications tab
│   │       ├── WebTab.qml       # Web search tab
│   │       ├── FileTab.qml      # File search tab
│   │       ├── GitTab.qml       # Git repos tab
│   │       └── BookmarksTab.qml  # Bookmarks tab
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

## Apps Popup

The `Apps.qml` popup provides a 5-tab launcher:

| Tab | Prefix | Content |
|-----|--------|---------|
| APPS | (none) | Desktop applications |
| WEB | `!` | Web search history |
| FILES | `@` | File search via `fd` + `fzf` |
| GIT | `#` | GitHub repos (requires `GITHUB_TOKEN`) |
| BMK | `~` | Bookmarks (add/delete) |

**Tab navigation**: Tab key cycles tabs, prefix keys switch directly.

**GitHub token**: Set `GITHUB_TOKEN` env var for private repo access.

### Helper Backend

The Rust helper (`helpers_rs/bins/get_apps_list`) uses SQLite for storage:

- `--web-search "!g rust"` - Save web search query, returns URL
- `--open-file "/path/to/file"` - Track file in history
- `--clear-web-history` / `--clear-file-history` - Clear history tables