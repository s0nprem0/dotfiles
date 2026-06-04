import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../Theme.js" as Theme
import "../../NotificationState.js" as State

FloatingWindow {
  id: centerPopup
  title: "notification_center"
  color: "transparent"
  visible: false

  implicitWidth: 400
  implicitHeight: 460

  Rectangle {
    anchors.fill: parent
    color: Theme.bg
    radius: 12
    border.color: Theme.surfaceLighter
    border.width: 1
    clip: true

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // ── Header ─────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        color: Theme.surfaceLighter

        Item {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.fg
            font.pixelSize: 15
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅖"
            color: Theme.muted
            font.pixelSize: 16
            MouseArea {
              anchors.fill: parent
              onClicked: centerPopup.visible = false
            }
          }
        }
      }

      // ── Actions ────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        color: "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 12

          Text {
            text: State.dnd ? "󰂛  DND On" : "󰂚  DND Off"
            color: State.dnd ? Theme.error : (State.server && State.server.trackedNotifications.count > 0 ? Theme.primary : Theme.muted)
            font.pixelSize: 11
            MouseArea {
              anchors.fill: parent
              onClicked: State.service.toggleDnd()
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            visible: State.server && State.server.trackedNotifications.count > 0
            text: "󰧨  Clear All"
            color: Theme.muted
            font.pixelSize: 11
            MouseArea {
              anchors.fill: parent
              onClicked: State.service.clearAll()
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.surfaceLighter
      }

      // ── Notification List ──────────────────────────────
      ListView {
        id: notifList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: State.server ? State.server.trackedNotifications : null
        spacing: 2

        delegate: Rectangle {
          width: notifList.width - 8
          height: notifDelegateLayout.implicitHeight + 16
          radius: 8
          color: mA.containsMouse ? Theme.surfaceLighter : "transparent"
          anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

          RowLayout {
            id: notifDelegateLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            ColumnLayout {
              spacing: 2
              Layout.fillWidth: true

              RowLayout {
                spacing: 6
                Layout.fillWidth: true

                Rectangle {
                  width: 8
                  height: 8
                  radius: 4
                  color: model.urgency === 2 ? Theme.error
                    : model.urgency === 1 ? Theme.primary
                    : Theme.muted
                  Layout.alignment: Qt.AlignVCenter
                }

                Text {
                  text: model.appName || "Notification"
                  color: Theme.muted
                  font.pixelSize: 10
                  font.bold: true
                }

                Item { Layout.fillWidth: true }
              }

              Text {
                text: model.summary
                color: Theme.fg
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                Layout.fillWidth: true
              }

              Text {
                text: model.body
                color: Qt.alpha(Theme.fg, 0.7)
                font.pixelSize: 11
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 3
                visible: text.length > 0
                Layout.fillWidth: true
              }
            }

            Text {
              text: "󰅖"
              color: Theme.muted
              font.pixelSize: 14
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  notifList.model.get(index).dismiss()
                }
              }
            }
          }

          MouseArea {
            id: mA
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
          }
        }

        // Empty state
        Text {
          anchors.centerIn: parent
          visible: notifList.count === 0
          text: "󰂜  No notifications"
          color: Theme.muted
          font.pixelSize: 13
        }
      }
    }
  }

  // ── Close on Escape ────────────────────────────────────
  Item {
    focus: true
    Keys.onEscapePressed: centerPopup.visible = false
    Component.onCompleted: forceActiveFocus()
  }
}
