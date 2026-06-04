import Quickshell.Services.SystemTray
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

Rectangle {
  id: root

  Theme { id: theme }

  height: 28
  implicitWidth: trayRepeater.count * 24 + 8
  radius: 10
  color: Qt.alpha(theme.surface, 0.4)
  border.color: Qt.alpha(theme.primary, 0.1)
  border.width: 1
  visible: trayRepeater.count > 0

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 4
    anchors.rightMargin: 4
    spacing: 2

    Repeater {
      id: trayRepeater
      model: SystemTray.items

      Item {
        required property var modelData
        width: 20
        height: 20

        Image {
          anchors.centerIn: parent
          width: 16
          height: 16
          source: modelData.icon
          asynchronous: true
          sourceSize.width: 16
          sourceSize.height: 16
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          text: modelData.title ? modelData.title.charAt(0).toUpperCase() : "?"
          color: theme.fg
          font.family: theme.fontFamily
          font.pixelSize: 10
          visible: parent.children[0].status !== Image.Ready
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (modelData.menu && modelData.hasMenu)
              modelData.menu.popup()
            else
              modelData.activate()
          }
        }
      }
    }
  }
}
