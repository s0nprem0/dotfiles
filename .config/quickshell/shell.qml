import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

import "Theme.js" as Theme
import "components"
import "modules"

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 36
  color: "transparent"

  // ── Background ───────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color: {
      Theme.helperDir = Quickshell.env("HOME") + "/.config/quickshell/helpers";
      return Qt.alpha(Theme.bg, 0.65);
    }
    border.color: Qt.alpha(Theme.primary, 0.15)
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.alpha(Theme.primary, 0.15)
    }
  }

  // ── Main bar layout ─────────────────────────────────────
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 0

    // LEFT
    RowLayout {
      spacing: 0
      Layout.alignment: Qt.AlignVCenter

      Workspaces {}

      Text {
        id: windowTitle
        text: {
          var win = Hyprland.focusedWindow
          if (!win) return ""
          var title = win.title
          if (!title || title === "") return ""
          return title
        }
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        visible: text.length > 0
        Layout.leftMargin: 8
        Layout.preferredWidth: 350
        Layout.maximumWidth: 450
      }
    }

    Item { Layout.fillWidth: true }

    Item {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignCenter
      implicitWidth: 1
    }

    Item { Layout.fillWidth: true }

    // RIGHT
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

  // ── Truly centered clock overlay ────────────────────────
  Clock {
    anchors.centerIn: parent
  }
}
