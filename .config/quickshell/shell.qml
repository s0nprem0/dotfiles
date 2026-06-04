import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
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

  // ── Network State ──────────────────────────────────────
  property string networkSsid: ""
  property bool networkConnected: false

  // ── Swaync State ──────────────────────────────────────
  property int notificationCount: 0
  property bool dnd: false

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

      NetModule {
        networkConnected: root.networkConnected
        networkSsid: root.networkSsid
      }

      Audio {}

      Battery {}

      Tray {}

      Notifications {
        notificationCount: root.notificationCount
        dnd: root.dnd
      }
    }
  }

  // ── Periodic Network Poll ──────────────────────────────
  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: netProc.running = true
  }
  Component.onCompleted: netProc.running = true

  Process {
    id: netProc
    command: ["nmcli", "-g", "ACTIVE,SSID", "d", "w"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    stdout: SplitParser {
      onRead: function(data) {
        if (!data) return
        var idx = data.indexOf(":")
        if (idx > 0) {
          root.networkConnected = data.slice(0, idx) === "yes"
          root.networkSsid = data.slice(idx + 1)
        }
      }
    }
  }

  // ── Swaync Listener ────────────────────────────────────
  Process {
    id: swayncSub
    running: true
    command: ["swaync-client", "--subscribe-waybar"]
    stdout: SplitParser {
      onRead: function(data) {
        if (!data) return
        try {
          var j = JSON.parse(data)
          if (j.hasOwnProperty("count")) root.notificationCount = j.count
          if (j.hasOwnProperty("dnd")) root.dnd = j.dnd
        } catch (e) {}
      }
    }
  }
}
