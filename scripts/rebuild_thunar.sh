#!/usr/bin/env bash
set -uo pipefail

THEME_DIR="$HOME/.themes/MaterialO"
COLORS_FILE="$HOME/.config/gtk-3.0/colors.css"

log() { [[ "$VERBOSE" == "true" ]] && echo "[MaterialO] $*"; }

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "Error: $COLORS_FILE not found. Run theme_switcher first." >&2
    exit 1
fi

log "Building MaterialO theme..."

mkdir -p "$THEME_DIR/gtk-3.0" "$THEME_DIR/gtk-4.0"

log "Generating GTK3 styles..."
cat > "$THEME_DIR/gtk-3.0/gtk.css" << 'EOF'
@import url("colors.css");

/* Thunar window decorations */
.window-frame {
    border-radius: 0;
    box-shadow: none;
}

/* Menu bar - solid dark */
.menu-bar {
    background-color: @bg_color;
    border: none;
}

.menu-bar .button {
    background: transparent;
    border: none;
    padding: 2px 6px;
}

.menu-bar .button:hover {
    background-color: @primary_color;
}

/* Loading icon fix */
.menu-bar spinner {
    display: none;
}

.menu-bar .arrow {
    color: @fg_color;
}

/* Sidebar styling */
.sidebar {
    background-color: @base_color;
    border-right: 1px solid @border_color;
}

.sidebar .view {
    background-color: @base_color;
}

/* Toolbar */
.toolbar {
    background-color: @bg_color;
    border-bottom: 1px solid @border_color;
}

.toolbar .button {
    margin: 2px;
}

/* Path bar */
.path-bar {
    border-bottom: 1px solid @border_color;
}

/* Location bar */
.location-bar {
    background-color: @bg_color;
}

/* Icon view */
.icon-view .tile {
    background-color: transparent;
    border-radius: 0;
}

.icon-view .tile:selected {
    background-color: @selected_bg_color;
}

/* List view */
.view.list-view {
    background-color: @base_color;
}

/* Scrollbars */
.scrollbar {
    background-color: alpha(black, 0.4);
}

.scrollbar slider {
    background-color: @fg_color;
    border-radius: 0;
}
EOF

log "Generating GTK4 styles..."
cat > "$THEME_DIR/gtk-4.0/gtk.css" << 'EOF'
@import url("colors.css");

/* Thunar window */
.window-frame {
    border-radius: 0;
    box-shadow: none;
}

/* Menu bar - solid dark */
.menu-bar {
    background-color: @bg_color;
}

.menu-bar .button {
    background: transparent;
    border: none;
}

.menu-bar .button:hover {
    background-color: @primary_color;
}

/* Loading icon fix */
.menu-bar spinner {
    display: none;
}

/* Sidebar */
.sidebar {
    background-color: @base_color;
}

/* Toolbar */
.toolbar {
    background-color: @bg_color;
}

/* Icon view */
.icon-view.tile {
    background-color: transparent;
    border-radius: 0;
}

.icon-view.tile:selected {
    background-color: @selected_bg_color;
}
EOF

log "Copying color definitions..."
cp "$COLORS_FILE" "$THEME_DIR/gtk-3.0/colors.css"
cp "$COLORS_FILE" "$THEME_DIR/gtk-4.0/colors.css"

if command -v gtk-builder-tool &>/dev/null; then
    log "Compiling GTK resources..."
    gtk-builder-tool simplify \
        /usr/share/themes/Adwaita-dark/gtk-3.0/gtk.gresource \
        --output=$THEME_DIR/gtk-3.0/gtk.gresource 2>/dev/null || true
    gtk-builder-tool simplify \
        /usr/share/themes/Adwaita-dark/gtk-4.0/gtk.gresource \
        --output=$THEME_DIR/gtk-4.0/gtk.gresource 2>/dev/null || true
fi

log "Setting theme..."
gsettings set org.gnome.desktop.interface gtk-theme "MaterialO"

echo "✓ MaterialO theme ready for Thunar"
echo "  Theme directory: $THEME_DIR"
echo "  Set GTK theme to: MaterialO"