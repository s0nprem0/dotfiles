import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../Theme.js" as Theme

Rectangle {
  id: root

  color: Qt.alpha(Theme.surface, 0.3)
  border.color: Qt.alpha(Theme.primary, 0.1)
  border.width: 1
  radius: 10
  height: 28
  implicitWidth: 130

  Process { id: wsRunner }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 4
    anchors.rightMargin: 4
    spacing: 1

    Repeater {
      model: 5

      Rectangle {
        id: wsBtn
        required property int index
        property var ws: Hyprland.workspaces.values.find(function(w) { return w.id === index + 1 })
        property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === index + 1 : false

        width: 28
        height: 24
        radius: 8
        color: isActive ? Qt.alpha(Theme.primary, 0.25) : "transparent"
        border.color: isActive ? Theme.primary : "transparent"
        border.width: isActive ? 1 : 0

        Text {
          anchors.centerIn: parent
          text: index + 1
          color: isActive ? Theme.bg : (ws ? Theme.fg : Qt.alpha(Theme.fg, 0.3))
          font.family: Theme.fontFamily
          font.pixelSize: 11
          font.bold: isActive
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: if (!isActive) parent.color = Qt.alpha(Theme.primary, 0.15)
          onExited: if (!isActive) parent.color = "transparent"
          onClicked: {
            wsRunner.command = ["hyprctl", "dispatch", "workspace", String(index + 1)]
            wsRunner.running = true
          }
        }
      }
    }
  }
}
