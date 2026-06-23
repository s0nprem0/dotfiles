#!/usr/bin/env bash
set -uo pipefail

THEME_DIR="$HOME/.themes/MaterialO"
COLORS_FILE="$HOME/.config/gtk-3.0/colors.css"

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "Error: $COLORS_FILE not found. Run theme_switcher first." >&2
    exit 1
fi

mkdir -p "$THEME_DIR/gtk-3.0" "$THEME_DIR/gtk-4.0"

cat > "$THEME_DIR/gtk-3.0/gtk.css" << 'EOF'
@import url("colors.css");

/* Thunar-specific overrides */
.window-frame {
    border-radius: 0;
}

/* Transparent menu bar */
.menu-bar {
    background-color: alpha(currentColor, 0.05);
}

/* Sidebar */
.sidebar {
    background-color: @base_color;
}

/* Toolbar */
.toolbar {
    background-color: @toolbar_bg_color;
}
EOF

cat > "$THEME_DIR/gtk-4.0/gtk.css" << 'EOF'
@import url("colors.css");

.window-frame {
    border-radius: 0;
}

.menu-bar {
    background-color: alpha(currentColor, 0.05);
}

.sidebar {
    background-color: @base_color;
}

.toolbar {
    background-color: @toolbar_bg_color;
}
EOF

cp "$COLORS_FILE" "$THEME_DIR/gtk-3.0/colors.css"
cp "$COLORS_FILE" "$THEME_DIR/gtk-4.0/colors.css"

if command -v gtk-builder-tool &>/dev/null; then
    gtk-builder-tool simplify \
        /usr/share/themes/Adwaita-dark/gtk-3.0/gtk.gresource \
        --output=$THEME_DIR/gtk-3.0/gtk.gresource 2>/dev/null || true
    gtk-builder-tool simplify \
        /usr/share/themes/Adwaita-dark/gtk-4.0/gtk.gresource \
        --output=$THEME_DIR/gtk-4.0/gtk.gresource 2>/dev/null || true
fi

gsettings set org.gnome.desktop.interface gtk-theme "MaterialO"
echo "MaterialO theme rebuilt for Thunar"