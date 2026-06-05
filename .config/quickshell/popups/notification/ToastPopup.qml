import Quickshell
import QtQuick
import QtQuick.Layouts

import "../.."
import "../../NotificationState.js" as State

FloatingWindow {
  id: toastPopup
  title: "notification_toast"
  color: "transparent"
  visible: toastRepeater.count > 0

  implicitWidth: 360
  implicitHeight: toastColumn.height + 16

  Rectangle {
    anchors.fill: parent
    color: "transparent"

    Column {
      id: toastColumn
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 8
      anchors.rightMargin: 8
      spacing: 6

      Repeater {
        id: toastRepeater
        model: State.toastModel

        delegate: Rectangle {
          id: card
          width: 344
          height: cardLayout.implicitHeight + 20
          radius: 10
          color: Theme.surface
          border.color: borderColor
          border.width: 1
          clip: true

          readonly property int urg: model.urgency
          readonly property color borderColor: urg === 2 ? Theme.error : urg === 1 ? Theme.primary : Theme.surfaceLighter

          opacity: 1
          Behavior on opacity { NumberAnimation { duration: 200 } }

          Timer {
            id: dismissTimer
            interval: model.expireTimeout > 0
              ? Math.min(model.expireTimeout * 1000, 10000)
              : model.urgency === 2 ? 10000 : 5000
            running: true
            onTriggered: {
              card.opacity = 0
              fadeTimer.start()
            }
          }

          Timer {
            id: fadeTimer
            interval: 200
            onTriggered: State.service.dismissToast(index)
          }

          RowLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            ColumnLayout {
              spacing: 2
              Layout.fillWidth: true

              Text {
                text: model.appName || "Notification"
                color: Theme.muted
                font.pixelSize: 10
                font.bold: true
              }

              Text {
                text: model.summary
                color: Theme.fg
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
              }

              Text {
                text: model.body
                color: Qt.alpha(Theme.fg, 0.7)
                font.pixelSize: 11
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                visible: text.length > 0
              }
            }

            Text {
              text: "󰅖"
              color: Theme.muted
              font.pixelSize: 14
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  dismissTimer.stop()
                  card.opacity = 0
                  fadeTimer.start()
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
              dismissTimer.stop()
              card.opacity = 0
              fadeTimer.start()
            }
          }
        }
      }
    }
  }
}
