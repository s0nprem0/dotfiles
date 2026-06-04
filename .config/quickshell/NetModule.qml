import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

Rectangle {
  id: root

  Theme { id: theme }

  height: 28
  implicitWidth: netLabel.implicitWidth + 20
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(theme.primary, 0.3) : Qt.alpha(theme.primary, 0.1)
  border.width: 1

  Process { id: nmRunner }

  property bool networkConnected: false
  property string networkSsid: ""

  RowLayout {
    anchors.centerIn: parent
    spacing: 4

    Text {
      id: netIcon
      text: root.networkConnected ? "󰤨" : "󰤭"
      color: root.networkConnected ? theme.fg : theme.muted
      font.family: theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: netLabel
      text: root.networkConnected ? root.networkSsid : "Disconnected"
      color: root.networkConnected ? Qt.alpha(theme.fg, 0.7) : theme.muted
      font.family: theme.fontFamily
      font.pixelSize: 10
      visible: text.length > 0
    }
  }

  Rectangle {
    id: netTooltip
    anchors.bottom: parent.top
    anchors.bottomMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    height: 20
    width: netTooltipText.width + 12
    radius: 4
    color: Qt.alpha(theme.surface, 0.9)
    border.color: Qt.alpha(theme.primary, 0.2)
    border.width: 1
    visible: mA.containsMouse

    Text {
      id: netTooltipText
      anchors.centerIn: parent
      text: root.networkConnected ? root.networkSsid : "Disconnected"
      color: theme.fg
      font.family: theme.fontFamily
      font.pixelSize: 9
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        nmRunner.command = ["nm-connection-editor"]
        nmRunner.running = true
      } else {
        nmRunner.command = ["qs", "-p", "/home/jllyn/.config/quickshell/wifi.qml"]
        nmRunner.running = true
      }
    }
  }
}
