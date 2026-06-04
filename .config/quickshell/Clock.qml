import QtQuick
import QtQuick.Layouts

Text {
  id: root

  Theme { id: theme }

  text: Qt.formatDateTime(new Date(), "ddd MMM d  hh:mm")
  color: theme.fg
  font.family: theme.fontFamily
  font.pixelSize: 11
  font.bold: true
  Layout.alignment: Qt.AlignCenter

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.text = Qt.formatDateTime(new Date(), "ddd MMM d  hh:mm")
  }
}
