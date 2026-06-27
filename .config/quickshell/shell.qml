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
        PopupManager.register("apps", appsPopup);
        PopupManager.register("network", networkPopup);
        PopupManager.register("clipboard", clipboardPopup);
        PopupManager.register("media", mediaPopup);
        PopupManager.register("battery", batteryPopup);
        PopupManager.register("emoji", emojiPopup);
        PopupManager.register("settings", settingsPopup);
        PopupManager.register("workspace", workspacePopup);
        PopupManager.register("shortcut", shortcutPopup);
        PopupManager.register("tray", trayPopup);
        PopupManager.register("theme-picker", themePickerPopup);
        PopupManager.register("notifications", centerPopup);
        PopupManager.register("ports", portsPopup);
        PopupManager.register("sysmon", sysmonPopup);
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

            Caffeine {
            }

            ThemePicker {
                themePickerPopupRef: themePickerPopup
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
            PopupManager.toggle(name);
        }
    }

    // Popups
    Popups.Apps {
        id: appsPopup
    }

    Popups.Network {
        id: networkPopup
        popupName: "network"
    }

    Popups.Clipboard {
        id: clipboardPopup
        popupName: "clipboard"
    }

    Popups.Media {
        id: mediaPopup
        popupName: "media"

        audioBarRef: audioModule
    }

    Popups.Battery {
        id: batteryPopup
        popupName: "battery"
    }

    Popups.Emoji {
        id: emojiPopup
        popupName: "emoji"
    }

    Popups.Settings {
        id: settingsPopup
    }

    Popups.Workspace {
        id: workspacePopup
        popupName: "workspace"
    }

    Popups.Shortcut {
        id: shortcutPopup
        popupName: "shortcut"
    }

    Popups.Tray {
        id: trayPopup
        popupName: "tray"
    }

    Popups.Ports {
        id: portsPopup
        popupName: "ports"
    }

    Popups.Sysmon {
        id: sysmonPopup
        popupName: "sysmon"
    }

    Popups.ThemePicker {
        id: themePickerPopup
        popupName: "theme-picker"
    }
}
