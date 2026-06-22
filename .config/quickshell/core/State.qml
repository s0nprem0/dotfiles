pragma Singleton
import QtQuick

QtObject {

    // System
    property int batteryPercent: 0
    property bool batteryCharging: false

    property int volume: 0
    property bool muted: false

    property int brightness: 0

    // Network
    property bool wifiEnabled: false
    property string wifiSsid: ""

    // Hyprland
    property int activeWorkspace: 1
    property string activeWindowTitle: ""

    // Theme
    property string accent: ""
    property string surface: ""

    // Notifications
    property int notificationCount: 0

    // Media
    property string mediaTitle: ""
    property string mediaArtist: ""
}
