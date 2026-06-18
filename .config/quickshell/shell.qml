import QtQuick
import QtQuick.Layouts
import "bar"
import "components"
import "popups" as Popups
import "popups/notification" as Notif
import Quickshell.Io
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
            }

            Tray {
                trayPopupRef: trayPopup
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

    // IPC-callable toggle from keybindings (qs ipc call shell togglePopup <name>)
    IpcHandler {
        target: "shell"
        function togglePopup(name: string): void {
            switch (name) {
                case "apps": appsPopup.showPopup = !appsPopup.showPopup; break;
                case "clipboard": clipboardPopup.showPopup = !clipboardPopup.showPopup; break;
                case "emoji": emojiPopup.showPopup = !emojiPopup.showPopup; break;
                case "media": mediaPopup.showPopup = !mediaPopup.showPopup; break;
                case "network": networkPopup.showPopup = !networkPopup.showPopup; break;
                case "battery": batteryPopup.showPopup = !batteryPopup.showPopup; break;
                case "settings": settingsPopup.showPopup = !settingsPopup.showPopup; break;
                case "workspace": workspacePopup.showPopup = !workspacePopup.showPopup; break;
                case "shortcut": shortcutPopup.showPopup = !shortcutPopup.showPopup; break;
                case "notifications": centerPopup.showPopup = !centerPopup.showPopup; break;
                case "tray": trayPopup.showPopup = !trayPopup.showPopup; break;
            }
        }
    }

    // Popups
    Popups.Apps {
        id: appsPopup
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

    Popups.Battery {
        id: batteryPopup
    }

    Popups.Emoji {
        id: emojiPopup
    }

    Popups.Settings {
        id: settingsPopup
    }

    Popups.Workspace {
        id: workspacePopup
    }

    Popups.Shortcut {
        id: shortcutPopup
    }

    Popups.Tray {
        id: trayPopup
    }

}
