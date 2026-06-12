import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "bar"
import "components"
import "popups" as Popups
import "popups/notification" as Notif
import "service"

Bar {
    Component.onCompleted: {
        NotificationState.centerPopup = centerPopup;
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // LEFT SECTION
        RowLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Workspaces {
                Layout.rightMargin: 8
            }

        }

        Item {
            Layout.fillWidth: true
        }

        // RIGHT SECTION
        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignVCenter

            Bluetooth {
            }

            Notifications {
                notifService: notifService
            }

            Tray {
            }

            Emoji {
                emojiPopupRef: emojiPopup
            }

            Clipboard {
                clipboardPopupRef: clipboardPopup
            }

            Audio {
                id: audioModule

                mediaPopupRef: mediaPopup
            }

            Battery {
                batteryPopupRef: batteryPopup
            }

            Network {
            }

            Settings {
                settingsPopupRef: settingsPopup
            }

        }

    }

    // Centered Clock
    Clock {
        anchors.centerIn: parent
    }

    // OSD
    OsdWindow {
    }

    // Notification System
    Notif.NotificationService {
        id: notifService
    }

    Notif.ToastPopup {
    }

    Notif.CenterPopup {
        id: centerPopup
    }

    // Popups
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

    Popups.Battery {
        id: batteryPopup
    }

    Popups.Emoji {
        id: emojiPopup
    }

    Popups.Settings {
        id: settingsPopup
    }

}
