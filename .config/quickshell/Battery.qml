import Quickshell
import QtQuick
import QtQuick.Layouts

import "Theme.js" as Theme

BarModule {
  id: root

  implicitWidth: battLabel.x + battLabel.implicitWidth + 10
  visible: batteryDevice !== null

  border.color: {
    if (mA.containsMouse) return Qt.alpha(Theme.primary, 0.3)
    if (root.battCritical) return Theme.error
    if (root.battWarning) return Theme.warning
    if (root.charging) return Qt.alpha("#a6e3a1", 0.4)
    return Qt.alpha(Theme.primary, 0.1)
  }

  property var batteryDevice: null
  property int pct: 0
  property bool charging: false
  property string healthStr: ""
  property string powerStr: ""
  property string timeStr: ""
  property bool battWarning: !charging && pct <= 20
  property bool battCritical: !charging && pct <= 10

  property int animFrame: 0
  readonly property var chargingIcons: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝"]

  DataModule {
    path: Quickshell.env("HOME") + "/.config/quickshell/helpers/get_battery_status"
    interval: 10000
    onDataReceived: function(j) {
      root.pct = j.capacity
      root.charging = String(j.status).toLowerCase().includes("charging")
        || String(j.status).toLowerCase().includes("fully")
      root.healthStr = "Health: " + j.health + "%"
      root.powerStr = "Power: " + j.power_draw_w + "W"
      root.timeStr = j.time_remaining
      root.batteryDevice = j
    }
  }

  Timer {
    id: batteryAnim
    interval: 500
    running: root.charging && root.pct < 100
    repeat: true
    onTriggered: root.animFrame = (root.animFrame + 1) % root.chargingIcons.length
  }

  tooltipText: root.pct + "%" + (root.charging ? " (charging)" : "") + " - " + root.timeStr + " | " + root.healthStr + " | " + root.powerStr
  tooltipVisible: root.batteryDevice !== null

  RowLayout {
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: {
        if (!root.batteryDevice) return ""
        if (root.charging && root.pct >= 100) return "󰂄"
        if (root.charging) return root.chargingIcons[root.animFrame]
        if (root.pct >= 90) return "󰁹"
        if (root.pct >= 80) return "󰂂"
        if (root.pct >= 70) return "󰂁"
        if (root.pct >= 60) return "󰂀"
        if (root.pct >= 50) return "󰁿"
        if (root.pct >= 40) return "󰁾"
        if (root.pct >= 30) return "󰁽"
        if (root.pct >= 20) return "󰁼"
        if (root.pct >= 10) return "󰁻"
        return "󰁺"
      }
      color: root.battCritical ? Theme.error : root.battWarning ? Theme.warning : (root.charging ? "#a6e3a1" : Theme.fg)
      font.family: Theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: battLabel
      text: root.pct + "%"
      color: Qt.alpha(Theme.fg, 0.7)
      font.family: Theme.fontFamily
      font.pixelSize: 10
    }
  }
}
