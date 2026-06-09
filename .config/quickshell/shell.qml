import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "service"
import "components"
import "bar"
import "popups" as Popups
import "popups/notification" as Notif

Bar {
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // LEFT
        RowLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Workspaces {
                Layout.rightMargin: 8
            }

            Text {
                id: windowTitle
                text: {
                    var win = Hyprland.focusedWindow
                    if (!win) return ""
                    var title = win.title
                    if (!title || title === "") return ""
                    return title
                }
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                visible: text.length > 0
                Layout.leftMargin: 8
                Layout.maximumWidth: 350
            }
        }

        Item { Layout.fillWidth: true }

        // RIGHT
        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignVCenter
            Bluetooth {}
            Notifications { notifService: notifService }
            Tray {}
            Clipboard { clipboardPopupRef: clipboardPopup }
            Audio { id: audioModule; mediaPopupRef: mediaPopup }
            Battery {}
            Network {}
            Settings { settingsPopupRef: settingsPopup }
        }
    }

    // ── Centered clock overlay ──────────────────────────────
    Clock {
        anchors.centerIn: parent
    }

    // ── Notification System ─────────────────────────────────
    Notif.NotificationService { id: notifService }

    Notif.ToastPopup { }

    Notif.CenterPopup {
        id: centerPopup
    }

    Popups.Network {
        id: networkPopup
    }

    Popups.Clipboard {
        id: clipboardPopup
    }

    Popups.Media {
        id: mediaPopup
        audioBarRef: audioModule
    }

    Popups.Settings {
        id: settingsPopup
    }

    Component.onCompleted: {
        NotificationState.centerPopup = centerPopup
    }
}
