import QtQuick

import "../service"

Rectangle {
  id: root

  property alias mA: mA
  property alias tooltipText: tooltipLabel.text
  property bool tooltipVisible: tooltipLabel.text.length > 0
  property int acceptedButtons: Qt.LeftButton

  // NEW: Allow changing tooltip direction based on bar placement (top vs bottom)
  property bool tooltipBelow: true
  property bool loading: false
  property bool error: false

  height: 28

  Behavior on color { ColorAnimation { duration: 80 } }
  Behavior on border.color { ColorAnimation { duration: 80 } }

  color: root.error
    ? Qt.alpha("#e06c75", 0.3)
    : root.loading
      ? Qt.alpha("#e5c07b", 0.25)
      : mA.containsMouse ? Qt.alpha(Theme.primary, 0.2) : Qt.alpha(Theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.3) : Qt.alpha(Theme.primary, 0.1)
  border.width: 1

  Rectangle {
    id: tooltip

    // NEW: Dynamic anchoring to prevent screen clipping
    anchors.top: root.tooltipBelow ? parent.bottom : undefined
    anchors.bottom: !root.tooltipBelow ? parent.top : undefined
    anchors.topMargin: root.tooltipBelow ? 4 : 0
    anchors.bottomMargin: !root.tooltipBelow ? 4 : 0
    anchors.horizontalCenter: parent.horizontalCenter

    height: 20
    width: tooltipLabel.width + 12
    radius: 4 // Slightly softer tooltip radius

    color: Qt.alpha(Theme.surface, 0.9)
    border.color: Qt.alpha(Theme.primary, 0.2)
    border.width: 1

    // NEW: Animate the tooltip fading in and out
    opacity: (mA.containsMouse && root.tooltipVisible) ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: 10
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: root.acceptedButtons
    cursorShape: Qt.PointingHandCursor // NEW: Shows the hand icon on hover
  }
}
