import QtQuick

import "../service"

Text {
  id: root

  readonly property string dateFormat: "ddd MMM d hh:mm"

  text: Qt.formatDateTime(new Date(), root.dateFormat)
  color: Theme.fg
  font.family: Theme.fontFamily
  font.pixelSize: 11
  font.bold: true

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.text = Qt.formatDateTime(new Date(), root.dateFormat)
  }
}
