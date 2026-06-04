import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 36
  color: "transparent"

  Theme { id: theme }

  // ── Background ───────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(theme.bg, 0.65)
    border.color: Qt.alpha(theme.primary, 0.15)
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.alpha(theme.primary, 0.15)
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 0

    // ── LEFT: Workspaces + Window ──────────────────────
    RowLayout {
      spacing: 0
      Layout.alignment: Qt.AlignVCenter

      Workspaces {}

      // Window title
      Text {
        id: windowTitle
        text: {
          var win = Hyprland.focusedWindow
          if (!win) return ""
          var title = win.title
          if (!title || title === "") return ""
          return title
        }
        color: theme.fg
        font.family: theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        visible: text.length > 0
        Layout.leftMargin: 8
        Layout.preferredWidth: 350
        Layout.maximumWidth: 450
      }
    }

    Item { Layout.fillWidth: true }

    // ── CENTER: Clock ─────────────────────────
    Clock {}

    Item { Layout.fillWidth: true }

    // ── RIGHT: Modules ─────────────────────────────────
    RowLayout {
      spacing: 3
      Layout.alignment: Qt.AlignVCenter

      BtModule {}
      NetModule {}
      Audio {}
      Battery {}
      Tray {}
      Notifications {}
    }
  }
}
