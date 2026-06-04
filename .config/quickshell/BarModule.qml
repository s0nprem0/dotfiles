import QtQuick

import "Theme.js" as Theme

Rectangle {
  id: root

  property alias mA: mA
  property alias tooltipText: tooltipLabel.text
  property bool tooltipVisible: tooltipLabel.text.length > 0

  height: 28
  radius: 10

  color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.2) : Qt.alpha(Theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.3) : Qt.alpha(Theme.primary, 0.1)
  border.width: 1

  Rectangle {
    id: tooltip
    anchors.bottom: parent.top
    anchors.bottomMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    height: 20
    width: tooltipLabel.width + 12
    radius: 4
    color: Qt.alpha(Theme.surface, 0.9)
    border.color: Qt.alpha(Theme.primary, 0.2)
    border.width: 1
    visible: mA.containsMouse && root.tooltipVisible

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: 9
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
  }
}
