#!/usr/bin/env bash
set -uo pipefail

THEME_DIR="$HOME/.themes/MaterialO"
COLORS_FILE="$HOME/.config/gtk-3.0/colors.css"

log() { [[ "${VERBOSE:-false}" == "true" ]] && echo "[MaterialO] $*"; }

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "Error: $COLORS_FILE not found. Run theme_switcher first." >&2
    exit 1
fi

log "Building MaterialO theme..."

mkdir -p "$THEME_DIR/gtk-3.0" "$THEME_DIR/gtk-4.0"

log "Generating GTK3 styles..."
cat > "$THEME_DIR/gtk-3.0/gtk.css" << 'EOF'
@import url("colors.css");

/* ── Window ─────────────────────────────────── */
window.background, .window-frame {
    background-color: @base_color;
}

/* ── Menu bar ────────────────────────────────── */
.menu-bar {
    background-color: alpha(@bg_color, 0.95);
    border: none;
    border-bottom: 1px solid alpha(@border_color, 0.5);
}

.menu-bar .button {
    background: transparent;
    border: none;
    padding: 2px 8px;
    transition: background-color 120ms ease;
}

.menu-bar .button:hover {
    background-color: alpha(@primary_color, 0.2);
}

/* ── Toolbar ─────────────────────────────────── */
.toolbar {
    background-color: alpha(@bg_color, 0.9);
    border-bottom: 1px solid alpha(@border_color, 0.5);
    padding: 2px 4px;
}

.toolbar .button {
    margin: 1px;
    padding: 3px 8px;
    border-radius: 4px;
    transition: all 120ms ease;
}

.toolbar .button:hover {
    background-color: alpha(@primary_color, 0.15);
}

/* ── Location / Path bar ─────────────────────── */
.location-bar {
    background-color: alpha(@bg_color, 0.95);
    border-bottom: 1px solid alpha(@border_color, 0.5);
    padding: 2px 4px;
}

.path-bar {
    border-bottom: 1px solid alpha(@border_color, 0.5);
}

.path-bar .button {
    background: transparent;
    border: none;
    padding: 3px 10px;
    margin: 1px 0;
    transition: all 120ms ease;
}

.path-bar .button:hover {
    background-color: alpha(@primary_color, 0.15);
}

.path-bar .button:checked {
    background-color: alpha(@primary_color, 0.2);
    color: @primary_color;
}

/* ── Sidebar ─────────────────────────────────── */
.sidebar {
    background-color: alpha(@base_color, 0.95);
    border-right: 1px solid alpha(@border_color, 0.6);
}

.sidebar .view {
    background-color: transparent;
    border: none;
}

.sidebar .view:not(:selected):hover {
    background-color: alpha(@primary_color, 0.1);
}

.sidebar .view:selected {
    background-color: alpha(@primary_color, 0.2);
    color: @primary_color;
    font-weight: 600;
}

/* ── Column Headers ──────────────────────────── */
column-header .button {
    background-color: alpha(@bg_color, 0.8);
    border: none;
    border-bottom: 1px solid alpha(@primary_color, 0.3);
    padding: 4px 8px;
    font-weight: 600;
}

column-header .button:hover {
    background-color: alpha(@primary_color, 0.1);
    border-bottom-color: @primary_color;
}

/* ── Tree / List View ────────────────────────── */
treeview.view, .view.list-view {
    background-color: @base_color;
    color: @fg_color;
}

treeview.view:selected,
.view.list-view:selected {
    background-color: alpha(@primary_color, 0.25);
    color: @fg_color;
}

treeview.view:not(:selected):hover,
.view.list-view:not(:selected):hover {
    background-color: alpha(@primary_color, 0.07);
}

/* ── Icon View ───────────────────────────────── */
.icon-view .tile {
    background-color: transparent;
    border-radius: 6px;
    padding: 6px;
    transition: all 120ms ease;
}

.icon-view .tile:selected {
    background-color: alpha(@primary_color, 0.25);
    outline: 1px solid alpha(@primary_color, 0.4);
}

.icon-view .tile:hover:not(:selected) {
    background-color: alpha(@primary_color, 0.07);
}

.icon-view .tile .label {
    color: @fg_color;
}

/* ── Status Bar ──────────────────────────────── */
statusbar {
    background-color: alpha(@bg_color, 0.9);
    border-top: 1px solid alpha(@border_color, 0.4);
    padding: 2px 6px;
    font-size: 0.9em;
}

/* ── Search / Entry ──────────────────────────── */
entry.search-entry {
    background-color: alpha(@base_color, 0.9);
    border: 1px solid alpha(@border_color, 0.6);
    border-radius: 4px;
    padding: 3px 8px;
}

entry.search-entry:focus {
    border-color: @primary_color;
    outline: none;
}

/* ── Paned / Split ───────────────────────────── */
paned .separator {
    background-color: alpha(@border_color, 0.5);
}

paned .separator:hover {
    background-color: @primary_color;
}

/* ── Scrollbars ──────────────────────────────── */
.scrollbar {
    background-color: alpha(black, 0.15);
}

.scrollbar.vertical {
    width: 6px;
}

.scrollbar.horizontal {
    height: 6px;
}

.scrollbar slider {
    background-color: alpha(@fg_color, 0.3);
    border-radius: 3px;
    min-width: 6px;
    min-height: 6px;
}

.scrollbar slider:hover {
    background-color: alpha(@primary_color, 0.5);
}

/* ── Popover ─────────────────────────────────── */
popover, .popover {
    background-color: alpha(@bg_color, 0.97);
    border: 1px solid alpha(@border_color, 0.6);
}

/* ── Selection ───────────────────────────────── */
selection {
    background-color: alpha(@primary_color, 0.3);
}
EOF

log "Generating GTK4 styles..."
cat > "$THEME_DIR/gtk-4.0/gtk.css" << 'EOF'
@import url("colors.css");

/* ── Window ─────────────────────────────────── */
window.background {
    background-color: @base_color;
}

/* ── Header bar ──────────────────────────────── */
headerbar {
    background-color: alpha(@bg_color, 0.95);
    border-bottom: 1px solid alpha(@border_color, 0.5);
}

/* ── Menu bar ────────────────────────────────── */
.menu-bar {
    background-color: alpha(@bg_color, 0.95);
    border-bottom: 1px solid alpha(@border_color, 0.5);
}

.menu-bar .button {
    background: transparent;
    border: none;
    padding: 2px 8px;
    transition: background-color 120ms ease;
}

.menu-bar .button:hover {
    background-color: alpha(@primary_color, 0.2);
}

/* ── Toolbar ─────────────────────────────────── */
.toolbar {
    background-color: alpha(@bg_color, 0.9);
    border-bottom: 1px solid alpha(@border_color, 0.5);
}

.toolbar .button {
    border-radius: 4px;
    transition: all 120ms ease;
}

.toolbar .button:hover {
    background-color: alpha(@primary_color, 0.15);
}

/* ── Sidebar ─────────────────────────────────── */
.sidebar {
    background-color: alpha(@base_color, 0.95);
    border-right: 1px solid alpha(@border_color, 0.6);
}

.sidebar .view:not(:selected):hover {
    background-color: alpha(@primary_color, 0.1);
}

.sidebar .view:selected {
    background-color: alpha(@primary_color, 0.2);
    color: @primary_color;
}

/* ── Column Headers ──────────────────────────── */
columnheader button {
    background-color: alpha(@bg_color, 0.8);
    border-bottom: 1px solid alpha(@primary_color, 0.3);
    font-weight: 600;
}

columnheader button:hover {
    background-color: alpha(@primary_color, 0.1);
    border-bottom-color: @primary_color;
}

/* ── Icon View ───────────────────────────────── */
iconview .tile {
    background-color: transparent;
    border-radius: 6px;
    padding: 6px;
    transition: all 120ms ease;
}

iconview .tile:selected {
    background-color: alpha(@primary_color, 0.25);
    outline: 1px solid alpha(@primary_color, 0.4);
}

iconview .tile:hover:not(:selected) {
    background-color: alpha(@primary_color, 0.07);
}

/* ── Status Bar ──────────────────────────────── */
statusbar {
    background-color: alpha(@bg_color, 0.9);
    border-top: 1px solid alpha(@border_color, 0.4);
    padding: 2px 6px;
}

/* ── Entry ───────────────────────────────────── */
entry {
    border: 1px solid alpha(@border_color, 0.6);
    border-radius: 4px;
}

entry:focus {
    border-color: @primary_color;
}

/* ── Scrollbars ──────────────────────────────── */
scrollbar {
    background-color: alpha(black, 0.15);
}

scrollbar.vertical {
    width: 6px;
}

scrollbar.horizontal {
    height: 6px;
}

scrollbar slider {
    background-color: alpha(@fg_color, 0.3);
    border-radius: 3px;
    min-width: 6px;
    min-height: 6px;
}

scrollbar slider:hover {
    background-color: alpha(@primary_color, 0.5);
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

log "Setting GTK theme..."
gsettings set org.gnome.desktop.interface gtk-theme "MaterialO"

log "Setting icon theme..."
gsettings set org.gnome.desktop.interface icon-theme "macOS"

echo "✓ MaterialO theme ready for Thunar"
echo "  Theme directory: $THEME_DIR"
echo "  GTK theme: MaterialO"
echo "  Icon theme: macOS"
