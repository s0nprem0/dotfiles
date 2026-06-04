import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

Rectangle {
  id: root

  Theme { id: theme }

  height: 28
  implicitWidth: battLabel.x + battLabel.implicitWidth + 10
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: {
    if (mA.containsMouse) return Qt.alpha(theme.primary, 0.3)
    if (root.battCritical) return theme.error
    if (root.battWarning) return theme.warning
    if (root.charging) return Qt.alpha("#a6e3a1", 0.4)
    return Qt.alpha(theme.primary, 0.1)
  }
  border.width: 1
  visible: batteryDevice !== null

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

  Process {
    id: battHelper
    command: [Quickshell.env("HOME") + "/.config/quickshell/helpers/get_battery_status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(this.text)
          root.pct = j.capacity
          root.charging = String(j.status).toLowerCase().includes("charging")
            || String(j.status).toLowerCase().includes("fully")
          root.healthStr = "Health: " + j.health + "%"
          root.powerStr = "Power: " + j.power_draw_w + "W"
          root.timeStr = j.time_remaining
          root.batteryDevice = j
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: battHelper.running = true
  }

  Component.onCompleted: battHelper.running = true

  Timer {
    id: batteryAnim
    interval: 500
    running: root.charging && root.pct < 100
    repeat: true
    onTriggered: root.animFrame = (root.animFrame + 1) % root.chargingIcons.length
  }

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
      color: root.battCritical ? theme.error : root.battWarning ? theme.warning : (root.charging ? "#a6e3a1" : theme.fg)
      font.family: theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: battLabel
      text: root.pct + "%"
      color: Qt.alpha(theme.fg, 0.7)
      font.family: theme.fontFamily
      font.pixelSize: 10
    }
  }

  Rectangle {
    id: battTooltip
    anchors.bottom: parent.top
    anchors.bottomMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    height: 20
    width: battTooltipText.width + 12
    radius: 4
    color: Qt.alpha(theme.surface, 0.9)
    border.color: Qt.alpha(theme.primary, 0.2)
    border.width: 1
    visible: mA.containsMouse && root.batteryDevice

    Text {
      id: battTooltipText
      anchors.centerIn: parent
      text: root.pct + "%" + (root.charging ? " (charging)" : "") + " - " + root.timeStr + " | " + root.healthStr + " | " + root.powerStr
      color: theme.fg
      font.family: theme.fontFamily
      font.pixelSize: 9
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
  }
}
