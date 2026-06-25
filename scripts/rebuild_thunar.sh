#!/usr/bin/env bash
set -uo pipefail

THEME_DIR="$HOME/.themes/Supremo"
COLORS_FILE="$HOME/.config/gtk-3.0/colors.css"

log() { [[ "${VERBOSE:-false}" == "true" ]] && echo "[Supremo] $*"; }

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "Error: $COLORS_FILE not found. Run theme_switcher first." >&2
    exit 1
fi

log "Building Supremo theme..."

mkdir -p "$THEME_DIR/gtk-3.0" "$THEME_DIR/gtk-4.0"

log "Generating GTK3 styles..."
cat > "$THEME_DIR/gtk-3.0/gtk.css" << 'EOF'
@import url("colors.css");

/* ═══════════════════════════════════════════════
   Supremo GTK3 Theme — brutalist style
   ═══════════════════════════════════════════════ */

/* ── Global Reset ──────────────────────────── */
* {
    background-clip: padding-box;
    -gtk-outline-radius: 0;
    outline-color: alpha(@fg_color, 0.15);
    outline-style: solid;
    outline-width: 0;
    outline-offset: -4px;
}

/* ── Window ────────────────────────────────── */
window.background, .window-frame {
    background-color: @base_color;
    color: @fg_color;
}

window.background.csd {
    border-radius: 0;
}

/* ── Base States ───────────────────────────── */
*:disabled {
    -gtk-icon-effect: dim;
    color: alpha(@fg_color, 0.4);
}

.dim-label {
    color: alpha(@fg_color, 0.6);
}

separator {
    background-color: @border_color;
}

/* ── Entries & Spinbuttons ─────────────────── */
entry, spinbutton {
    min-height: 34px;
    padding: 0 8px;
    border-radius: 0;
    caret-color: currentColor;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

entry:focus, spinbutton:focus {
    border-color: @primary_color;
    background-color: @base_color;
}

entry:disabled, spinbutton:disabled {
    background-color: @base_color;
    color: alpha(@fg_color, 0.4);
    border-color: alpha(@border_color, 0.4);
}

entry selection, spinbutton selection {
    background-color: @selected_bg_color;
    color: @selected_fg_color;
}

/* ── Buttons ───────────────────────────────── */
button {
    min-height: 24px;
    min-width: 16px;
    padding: 5px 9px;
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button:active {
    background-color: @primary_color;
}

button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button:disabled {
    background-color: @base_color;
    color: alpha(@fg_color, 0.4);
    border-color: alpha(@border_color, 0.3);
}

button:focus {
    border-color: @primary_color;
}

button.flat {
    background-color: @base_color;
    border-color: transparent;
}

button.flat:hover {
    background-color: @fg_color;
    color: @base_color;
}

button.suggested-action {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button.suggested-action:hover {
    background-color: @primary_color;
}

button.destructive-action {
    background-color: @error_color;
    color: @selected_fg_color;
    border-color: @error_color;
}

button.destructive-action:hover {
    opacity: 0.85;
}

/* ── Linked Buttons ────────────────────────── */
.linked > button, .linked > spinbutton, .linked > entry {
    border-radius: 0;
}

.linked > button:first-child {
    border-top-left-radius: 0;
    border-bottom-left-radius: 0;
}

.linked > button:last-child {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
}

.linked > button:only-child {
    border-radius: 0;
}

/* ── Headerbar / Titlebar ──────────────────── */
headerbar, .titlebar {
    min-height: 40px;
    padding: 0 8px;
    background-color: @bg_color;
    color: @fg_color;
    border-bottom: 2px solid @border_color;
}

headerbar button, .titlebar button {
    border-color: transparent;
    background-color: @base_color;
}

headerbar button:hover, .titlebar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

headerbar button:checked, .titlebar button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Menu Bar ──────────────────────────────── */
.menu-bar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.menu-bar button {
    background-color: @base_color;
    border: none;
    padding: 2px 8px;
}

.menu-bar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

/* ── Toolbar ───────────────────────────────── */
.toolbar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.toolbar button {
    margin: 1px;
    padding: 3px 8px;
    border-radius: 0;
    border: 2px solid @border_color;
}

.toolbar button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

.inline-toolbar {
    background-color: @bg_color;
    padding: 6px;
    border: none;
}

/* ── Location / Path Bar ───────────────────── */
.location-bar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
    padding: 2px 4px;
}

.path-bar button {
    background-color: @base_color;
    border: none;
    padding: 3px 10px;
    margin: 1px 0;
    border: 2px solid @border_color;
}

.path-bar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

.path-bar button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Sidebar ───────────────────────────────── */
.sidebar {
    background-color: @base_color;
    border-right: 2px solid @border_color;
}

.sidebar .view {
    background-color: @base_color;
    border: none;
}

.sidebar .view:not(:selected):hover {
    background-color: @fg_color;
    color: @bg_color;
}

.sidebar .view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
    font-weight: 600;
}

placessidebar row {
    min-height: 28px;
    padding: 4px 8px;
    border-radius: 0;
}

placessidebar row:hover {
    background-color: @fg_color;
    color: @bg_color;
}

placessidebar row:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Column Headers ────────────────────────── */
column-header button {
    background-color: @bg_color;
    border: 2px solid @border_color;
    padding: 4px 8px;
    font-weight: 600;
    border-radius: 0;
}

column-header button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Tree / List View ──────────────────────── */
treeview.view {
    background-color: @base_color;
    color: @fg_color;
}

treeview.view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

treeview.view:not(:selected):hover {
    background-color: @surface;
}

treeview.view separator {
    background-color: @border_color;
}

/* ── Icon View ─────────────────────────────── */
iconview {
    background-color: @base_color;
    color: @fg_color;
}

iconview:selected {
    background-color: @primary_color;
}

iconview:hover:not(:selected) {
    background-color: @surface;
}

/* ── Notebook / Tabs ───────────────────────── */
notebook > header {
    background-color: @bg_color;
    border: none;
    border-bottom: 2px solid @border_color;
}

notebook > header tab {
    min-height: 28px;
    padding: 4px 12px;
    color: @fg_color;
    border: none;
    background-color: @base_color;
}

notebook > header tab:hover {
    color: @primary_color;
    background-color: @surface;
}

notebook > header tab:checked {
    color: @primary_color;
    background-color: @base_color;
    border-bottom: 2px solid @primary_color;
}

notebook > stack {
    background-color: @base_color;
    border: none;
}

/* ── Scale / Slider ────────────────────────── */
scale {
    padding: 8px 0;
}

scale trough {
    min-height: 4px;
    border-radius: 0;
    background-color: @border_color;
}

scale highlight {
    min-height: 4px;
    border-radius: 0;
    background-color: @primary_color;
}

scale slider {
    min-height: 16px;
    min-width: 16px;
    border-radius: 0;
    background-color: @surface;
    border: 2px solid @border_color;
    margin: -6px 0;
}

scale slider:hover {
    background-color: @primary_color;
    border-color: @primary_color;
}

scale slider:active {
    background-color: @primary_color;
    border-color: @primary_color;
}

/* ── Switch / Toggle ───────────────────────── */
switch {
    min-height: 22px;
    min-width: 44px;
    border-radius: 0;
    background-color: @surface;
    border: 2px solid @border_color;
}

switch:checked {
    background-color: @primary_color;
    border-color: @primary_color;
}

switch slider {
    min-height: 18px;
    min-width: 18px;
    border-radius: 0;
    background-color: @fg_color;
    margin: 2px;
}

switch:checked slider {
    background-color: @surface;
    margin-left: 24px;
}

/* ── Progress Bar ──────────────────────────── */
progressbar {
    min-height: 4px;
    border-radius: 0;
}

progressbar trough {
    background-color: @border_color;
    border-radius: 0;
}

progressbar progress {
    background-color: @primary_color;
    border-radius: 0;
}

/* ── Spinner ───────────────────────────────── */
spinner:active {
    color: @primary_color;
}

spinner:active > image {
    color: @primary_color;
}

spinner:disabled {
    color: alpha(@fg_color, 0.4);
}

/* ── Scrollbars ────────────────────────────── */
scrollbar {
    background-color: @base_color;
}

scrollbar.vertical {
    width: 12px;
}

scrollbar.horizontal {
    height: 12px;
}

scrollbar slider {
    background-color: @surface;
    border-radius: 0;
    min-width: 12px;
    min-height: 12px;
    border: 2px solid @border_color;
}

scrollbar slider:hover {
    background-color: @primary_color;
    border-color: @primary_color;
}

scrollbar slider:active {
    background-color: @primary_color;
    border-color: @primary_color;
}

/* ── Menus & Popovers ──────────────────────── */
menu {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
    padding: 4px 0;
}

menu menuitem {
    min-height: 16px;
    padding: 4px 8px;
    color: @fg_color;
}

menu menuitem:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

menu menuitem:disabled {
    color: alpha(@fg_color, 0.4);
}

menu separator {
    margin: 4px 0;
    background-color: @border_color;
}

menu menuitem accelerator {
    color: alpha(@fg_color, 0.6);
    margin-left: 16px;
}

popover.background {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
    border-radius: 0;
    padding: 4px 0;
}

popover.background menuitem {
    padding: 4px 8px;
}

popover.background menuitem:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Combobox ──────────────────────────────── */
combobox button.toggle {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

combobox button.toggle:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

combobox cellview {
    color: @fg_color;
}

/* ── Tooltip ───────────────────────────────── */
tooltip {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
    padding: 4px 8px;
}

tooltip * {
    border-radius: 0;
}

/* ── OSD ───────────────────────────────────── */
label.osd, button.osd {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

button.osd:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Flowbox ───────────────────────────────── */
flowbox flowboxchild {
    border-radius: 0;
    padding: 3px;
    border: 2px solid @border_color;
}

flowbox flowboxchild:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Expander ──────────────────────────────── */
expander arrow {
    min-width: 16px;
    min-height: 16px;
    border-radius: 0;
}

/* ── Color Button ──────────────────────────── */
colorbutton {
    border-radius: 0;
}

/* ── Info Bars ─────────────────────────────── */
infobar {
    border-radius: 0;
    border-style: none;
}

infobar > revealer > box {
    border-radius: 0;
}

/* ── Rubberband ────────────────────────────── */
rubberband, .rubberband,
treeview.view rubberband,
iconview rubberband,
.content-view rubberband {
    border: 2px solid @primary_color;
    background-color: @primary_color;
    border-radius: 0;
}

/* ── Dialog Action Area ────────────────────── */
.dialog-action-area button,
.dialog-action-box button,
window.dialog button {
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

.dialog-action-area button:hover,
.dialog-action-box button:hover,
window.dialog button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Status Bar ────────────────────────────── */
statusbar {
    background-color: @bg_color;
    border-top: 2px solid @border_color;
    padding: 2px 6px;
    font-size: 0.9em;
}

/* ── Paned Separator ───────────────────────── */
paned > separator {
    min-width: 2px;
    min-height: 2px;
    background-color: @border_color;
    border: none;
}

paned > separator:hover {
    background-color: @primary_color;
}

/* ── Links ─────────────────────────────────── */
*:link, link {
    color: @primary_color;
}

*:visited {
    color: alpha(@primary_color, 0.7);
}

/* ── Selection (broad override) ────────────── */
*:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

*:selected:focus {
    background-color: @primary_color;
}

/* ── Thunar Specific ───────────────────────── */
.thunar .view {
    background-color: @base_color;
    color: @fg_color;
}

.thunar .view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

.thunar .sidebar {
    background-color: @base_color;
}

.thunar .sidebar row:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

.thunar .sidebar row:hover {
    background-color: @surface;
}

.thunar toolbar, .thunar .primary-toolbar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.thunar .statusbar {
    background-color: @bg_color;
    color: @fg_color;
    border-top: 2px solid @border_color;
}

.thunar .dialog-vbox {
    background-color: @base_color;
}

.thunar infobar {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

.thunar notebook > header tab label {
    color: @fg_color;
}

.thunar notebook > header tab:checked label {
    color: @primary_color;
}

.thunar .view .rubberband,
.thunar iconview .rubberband {
    border: 2px solid @primary_color;
    background-color: @primary_color;
    border-radius: 0;
}
EOF

log "Generating GTK4 styles..."
cat > "$THEME_DIR/gtk-4.0/gtk.css" << 'EOF'
@import url("colors.css");

/* ═══════════════════════════════════════════════
   Supremo GTK4 Theme — brutalist style
   ═══════════════════════════════════════════════ */

/* ── Global Reset ──────────────────────────── */
* {
    background-clip: padding-box;
    -gtk-outline-radius: 0;
    outline-color: alpha(@fg_color, 0.15);
    outline-style: solid;
    outline-width: 0;
    outline-offset: -4px;
}

/* ── Window ────────────────────────────────── */
window.background {
    background-color: @base_color;
    color: @fg_color;
}

window.background.csd {
    border-radius: 0;
}

/* ── Base States ───────────────────────────── */
*:disabled {
    -gtk-icon-effect: dim;
    color: alpha(@fg_color, 0.4);
}

.dim-label {
    color: alpha(@fg_color, 0.6);
}

separator {
    background-color: @border_color;
}

/* ── Entries & Spinbuttons ─────────────────── */
entry, spinbutton {
    min-height: 34px;
    padding: 0 8px;
    border-radius: 0;
    caret-color: currentColor;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

entry:focus, spinbutton:focus {
    border-color: @primary_color;
    background-color: @base_color;
}

entry:disabled, spinbutton:disabled {
    background-color: @base_color;
    color: alpha(@fg_color, 0.4);
    border-color: alpha(@border_color, 0.4);
}

entry selection, spinbutton selection {
    background-color: @selected_bg_color;
    color: @selected_fg_color;
}

/* ── Buttons ───────────────────────────────── */
button {
    min-height: 24px;
    min-width: 16px;
    padding: 5px 9px;
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button:active {
    background-color: @primary_color;
}

button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button:disabled {
    background-color: @base_color;
    color: alpha(@fg_color, 0.4);
    border-color: alpha(@border_color, 0.3);
}

button:focus {
    border-color: @primary_color;
}

button.flat {
    background-color: @base_color;
    border-color: transparent;
}

button.flat:hover {
    background-color: @fg_color;
    color: @bg_color;
}

button.suggested-action {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

button.suggested-action:hover {
    background-color: @primary_color;
}

button.destructive-action {
    background-color: @error_color;
    color: @selected_fg_color;
    border-color: @error_color;
}

button.destructive-action:hover {
    opacity: 0.85;
}

/* ── Linked Buttons ────────────────────────── */
.linked > button, .linked > spinbutton, .linked > entry {
    border-radius: 0;
}

.linked > button:first-child {
    border-top-left-radius: 0;
    border-bottom-left-radius: 0;
}

.linked > button:last-child {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
}

.linked > button:only-child {
    border-radius: 0;
}

/* ── Headerbar / Titlebar ──────────────────── */
headerbar, .titlebar {
    min-height: 40px;
    padding: 0 8px;
    background-color: @bg_color;
    color: @fg_color;
    border-bottom: 2px solid @border_color;
}

headerbar button, .titlebar button {
    border-color: transparent;
    background-color: @base_color;
}

headerbar button:hover, .titlebar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

headerbar button:checked, .titlebar button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Menu Bar ──────────────────────────────── */
.menu-bar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.menu-bar button {
    background-color: @base_color;
    border: none;
    padding: 2px 8px;
}

.menu-bar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

/* ── Toolbar ───────────────────────────────── */
.toolbar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.toolbar button {
    margin: 1px;
    padding: 3px 8px;
    border-radius: 0;
    border: 2px solid @border_color;
}

.toolbar button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

.inline-toolbar {
    background-color: @bg_color;
    padding: 6px;
    border: none;
}

/* ── Location / Path Bar ───────────────────── */
.location-bar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
    padding: 2px 4px;
}

.path-bar button {
    background-color: @base_color;
    border: none;
    padding: 3px 10px;
    margin: 1px 0;
    border: 2px solid @border_color;
}

.path-bar button:hover {
    background-color: @fg_color;
    color: @bg_color;
}

.path-bar button:checked {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Sidebar ───────────────────────────────── */
.sidebar {
    background-color: @base_color;
    border-right: 2px solid @border_color;
}

.sidebar .view:not(:selected):hover {
    background-color: @fg_color;
    color: @bg_color;
}

.sidebar .view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

placessidebar row {
    min-height: 28px;
    padding: 4px 8px;
    border-radius: 0;
}

placessidebar row:hover {
    background-color: @fg_color;
    color: @bg_color;
}

placessidebar row:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Column Headers ────────────────────────── */
columnheader button {
    background-color: @bg_color;
    border: 2px solid @border_color;
    padding: 4px 8px;
    font-weight: 600;
    border-radius: 0;
}

columnheader button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Tree / List View ──────────────────────── */
treeview.view {
    background-color: @base_color;
    color: @fg_color;
}

treeview.view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

treeview.view:not(:selected):hover {
    background-color: @surface;
}

treeview.view separator {
    background-color: @border_color;
}

/* ── Icon View ─────────────────────────────── */
iconview {
    background-color: @base_color;
    color: @fg_color;
}

iconview:selected {
    background-color: @primary_color;
}

iconview:hover:not(:selected) {
    background-color: @surface;
}

/* ── Notebook / Tabs ───────────────────────── */
notebook > header {
    background-color: @bg_color;
    border: none;
    border-bottom: 2px solid @border_color;
}

notebook > header tab {
    min-height: 28px;
    padding: 4px 12px;
    color: @fg_color;
    border: none;
    background-color: @base_color;
}

notebook > header tab:hover {
    color: @primary_color;
    background-color: @surface;
}

notebook > header tab:checked {
    color: @primary_color;
    background-color: @base_color;
    border-bottom: 2px solid @primary_color;
}

notebook > stack {
    background-color: @base_color;
    border: none;
}

/* ── Scale / Slider ────────────────────────── */
scale {
    padding: 8px 0;
}

scale trough {
    min-height: 4px;
    border-radius: 0;
    background-color: @border_color;
}

scale highlight {
    min-height: 4px;
    border-radius: 0;
    background-color: @primary_color;
}

scale slider {
    min-height: 16px;
    min-width: 16px;
    border-radius: 0;
    background-color: @surface;
    border: 2px solid @border_color;
    margin: -6px 0;
}

scale slider:hover {
    background-color: @primary_color;
    border-color: @primary_color;
}

scale slider:active {
    background-color: @primary_color;
    border-color: @primary_color;
}

/* ── Switch / Toggle ───────────────────────── */
switch {
    min-height: 22px;
    min-width: 44px;
    border-radius: 0;
    background-color: @surface;
    border: 2px solid @border_color;
}

switch:checked {
    background-color: @primary_color;
    border-color: @primary_color;
}

switch slider {
    min-height: 18px;
    min-width: 18px;
    border-radius: 0;
    background-color: @fg_color;
    margin: 2px;
}

switch:checked slider {
    background-color: @surface;
    margin-left: 24px;
}

/* ── Progress Bar ──────────────────────────── */
progressbar {
    min-height: 4px;
    border-radius: 0;
}

progressbar trough {
    background-color: @border_color;
    border-radius: 0;
}

progressbar progress {
    background-color: @primary_color;
    border-radius: 0;
}

/* ── Spinner ───────────────────────────────── */
spinner:active {
    color: @primary_color;
}

spinner:active > image {
    color: @primary_color;
}

spinner:disabled {
    color: alpha(@fg_color, 0.4);
}

/* ── Scrollbars ────────────────────────────── */
scrollbar {
    background-color: @base_color;
}

scrollbar.vertical {
    width: 12px;
}

scrollbar.horizontal {
    height: 12px;
}

scrollbar slider {
    background-color: @surface;
    border-radius: 0;
    min-width: 12px;
    min-height: 12px;
    border: 2px solid @border_color;
}

scrollbar slider:hover {
    background-color: @primary_color;
    border-color: @primary_color;
}

scrollbar slider:active {
    background-color: @primary_color;
    border-color: @primary_color;
}

/* ── Menus & Popovers ──────────────────────── */
menu {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
    padding: 4px 0;
}

menu menuitem {
    min-height: 16px;
    padding: 4px 8px;
    color: @fg_color;
}

menu menuitem:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

menu menuitem:disabled {
    color: alpha(@fg_color, 0.4);
}

menu separator {
    margin: 4px 0;
    background-color: @border_color;
}

menu menuitem accelerator {
    color: alpha(@fg_color, 0.6);
    margin-left: 16px;
}

popover.background {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
    border-radius: 0;
    padding: 4px 0;
}

popover.background menuitem {
    padding: 4px 8px;
}

popover.background menuitem:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Combobox ──────────────────────────────── */
combobox button.toggle {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

combobox button.toggle:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

combobox cellview {
    color: @fg_color;
}

/* ── Tooltip ───────────────────────────────── */
tooltip {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
    padding: 4px 8px;
}

tooltip * {
    border-radius: 0;
}

/* ── OSD ───────────────────────────────────── */
label.osd, button.osd {
    border-radius: 0;
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

button.osd:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Flowbox ───────────────────────────────── */
flowbox flowboxchild {
    border-radius: 0;
    padding: 3px;
    border: 2px solid @border_color;
}

flowbox flowboxchild:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

/* ── Expander ──────────────────────────────── */
expander arrow {
    min-width: 16px;
    min-height: 16px;
    border-radius: 0;
}

/* ── Color Button ──────────────────────────── */
colorbutton {
    border-radius: 0;
}

/* ── Info Bars ─────────────────────────────── */
infobar {
    border-radius: 0;
    border-style: none;
}

infobar > revealer > box {
    border-radius: 0;
}

/* ── Rubberband ────────────────────────────── */
rubberband, .rubberband,
treeview.view rubberband,
iconview rubberband {
    border: 2px solid @primary_color;
    background-color: @primary_color;
    border-radius: 0;
}

/* ── Dialog Action Area ────────────────────── */
.dialog-action-area button,
window.dialog button {
    background-color: @base_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

.dialog-action-area button:hover,
window.dialog button:hover {
    background-color: @primary_color;
    color: @selected_fg_color;
    border-color: @primary_color;
}

/* ── Status Bar ────────────────────────────── */
statusbar {
    background-color: @bg_color;
    border-top: 2px solid @border_color;
    padding: 2px 6px;
    font-size: 0.9em;
}

/* ── Paned Separator ───────────────────────── */
paned > separator {
    min-width: 2px;
    min-height: 2px;
    background-color: @border_color;
    border: none;
}

paned > separator:hover {
    background-color: @primary_color;
}

/* ── Links ─────────────────────────────────── */
*:link, link {
    color: @primary_color;
}

*:visited {
    color: alpha(@primary_color, 0.7);
}

/* ── Selection (broad override) ────────────── */
*:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

*:selected:focus {
    background-color: @primary_color;
}

/* ── Thunar Specific ───────────────────────── */
.thunar .view {
    background-color: @base_color;
    color: @fg_color;
}

.thunar .view:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

.thunar .sidebar {
    background-color: @base_color;
}

.thunar .sidebar row:selected {
    background-color: @primary_color;
    color: @selected_fg_color;
}

.thunar .sidebar row:hover {
    background-color: @surface;
}

.thunar toolbar, .thunar .primary-toolbar {
    background-color: @bg_color;
    border-bottom: 2px solid @border_color;
}

.thunar .statusbar {
    background-color: @bg_color;
    color: @fg_color;
    border-top: 2px solid @border_color;
}

.thunar .dialog-vbox {
    background-color: @base_color;
}

.thunar infobar {
    background-color: @bg_color;
    color: @fg_color;
    border: 2px solid @border_color;
}

.thunar notebook > header tab label {
    color: @fg_color;
}

.thunar notebook > header tab:checked label {
    color: @primary_color;
}

.thunar .view .rubberband,
.thunar iconview .rubberband {
    border: 2px solid @primary_color;
    background-color: @primary_color;
    border-radius: 0;
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
gsettings set org.gnome.desktop.interface gtk-theme "Supremo"

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Supremo
gtk-icon-theme-name=macOS
gtk-font-name=GohuFont 14 Nerd Font Medium 11
gtk-cursor-theme-name=macOS
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Supremo
gtk-icon-theme-name=macOS
gtk-font-name=GohuFont 14 Nerd Font Medium 11
gtk-cursor-theme-name=macOS
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

log "Setting icon theme..."
gsettings set org.gnome.desktop.interface icon-theme "macOS"

echo "✓ Supremo theme ready for Thunar"
echo "  Theme directory: $THEME_DIR"
echo "  GTK theme: Supremo"
echo "  Icon theme: macOS"