import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import ".."

Rectangle {
  id: root

  color: Qt.alpha(Theme.surface, 0.3)
  border.color: Qt.alpha(Theme.primary, 0.1)
  border.width: 1
  radius: 10
  height: 28
  implicitWidth: 152

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

        property int wsId: index + 1
        property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
        property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === wsId : false
        property bool isUrgent: ws ? ws.urgent : false

        Layout.preferredWidth: 28
        Layout.preferredHeight: 24
        radius: 8

        border.color: isActive ? Theme.primary : (isUrgent ? Theme.warning : "transparent")
        border.width: isActive || isUrgent ? 1 : 0
        color: {
          if (isActive) return Qt.alpha(Theme.primary, 0.25)
          if (mouseArea.containsMouse) return Qt.alpha(Theme.primary, 0.15)
          return "transparent"
        }

        Behavior on color {
          ColorAnimation { duration: 150 }
        }

        Text {
          anchors.centerIn: parent
          text: wsBtn.wsId
          color: isActive ? Theme.bg : (ws ? Theme.fg : Qt.alpha(Theme.fg, 0.4))
          font.family: Theme.fontFamily
          font.pixelSize: 11
          font.bold: isActive
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true

          onClicked: {
            Hyprland.dispatch("workspace", String(wsBtn.wsId))
          }
        }
      }
    }
  }
}
