import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../components"
import "../service"

BarModule {
  id: root

  implicitWidth: contentRow.implicitWidth + 12
  visible: batteryDevice !== null

  border.color: {
    if (root.battCritical) return Theme.error
    if (root.battWarning) return Theme.warning
    if (root.charging) return Qt.alpha(Theme.green, 0.4)
    if (mA.containsMouse) return Qt.alpha(Theme.primary, 0.3)
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
    path: Theme.bin("get_battery_status")
    interval: 10000
    onDataReceived: function(j) {
      root.pct = j.capacity ?? 0
      var status = (j.status ?? "").toString().toLowerCase()
      root.charging = status === "charging" || status === "full"
      root.healthStr = j.health != null ? "Health: " + j.health + "%" : ""
      root.powerStr = j.power_draw_w != null ? "Power: " + j.power_draw_w + "W" : ""
      root.timeStr = j.time_remaining ?? ""
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

  acceptedButtons: Qt.LeftButton

  Process { id: runner }

  Connections {
    target: mA
    function onClicked(mouse) {
      runner.command = ["acpi", "-V"]
      runner.running = true
    }
  }

  tooltipText: {
    if (!root.batteryDevice) return ""
    var parts = [root.pct + "%"]
    if (root.charging) parts.push("(charging)")
    if (root.timeStr) parts.push("- " + root.timeStr)
    parts.push(root.healthStr)
    parts.push(root.powerStr)
    return parts.join(" ")
  }
  tooltipVisible: root.batteryDevice !== null

  RowLayout {
    id: contentRow
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
      color: root.battCritical ? Theme.error : root.battWarning ? Theme.warning : (root.charging ? Theme.green : Theme.fg)
      font.family: Theme.fontFamily
      font.pixelSize: 11
    }

    Text {
      id: battLabel
      text: root.pct + "%"
      color: Qt.alpha(Theme.fg, 0.7)
      font.family: Theme.fontFamily
      font.pixelSize: 11
    }
  }
}
