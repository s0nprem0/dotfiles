import QtQuick

import ".."

Text {
  id: root

  text: Qt.formatDateTime(new Date(), "ddd MMM d hh:mm")
  color: Theme.fg
  font.family: Theme.fontFamily
  font.pixelSize: 11
  font.bold: true

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.text = Qt.formatDateTime(new Date(), "ddd MMM d hh:mm")
  }
}
