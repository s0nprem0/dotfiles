import QtQuick

import "../service"

Item {
  id: root

  readonly property string dateFormat: "ddd MMM d hh:mm"

  width: clockText.implicitWidth + 16
  height: 28

  Text {
    id: clockText
    anchors.centerIn: parent
    text: Qt.formatDateTime(new Date(), root.dateFormat)
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: 11
    font.bold: true
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: clockText.text = Qt.formatDateTime(new Date(), root.dateFormat)
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (NotificationState.centerPopup)
        NotificationState.centerPopup.showPopup = true
    }
  }

  Rectangle {
    anchors.fill: parent
    color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
    border.color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.3) : "transparent"
    border.width: 1
    z: -1
  }
}
