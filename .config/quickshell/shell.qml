import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 36
  color: "transparent"

  // ── Waybar-like warm theme ─────────────────────────────
  property color _bg: "#19120d"
  property color _fg: "#f0dfd6"
  property color _surface: "#261e19"
  property color _primary: "#ffb785"
  property color _muted: Qt.alpha(_fg, 0.4)
  property color _error: "#f38ba8"
  property color _warning: "#f9e2af"

  // ── Network State ──────────────────────────────────────
  property string networkSsid: ""
  property bool networkConnected: false

  // ── Swaync State ──────────────────────────────────────
  property int notificationCount: 0
  property bool dnd: false

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(_bg, 0.65)
    border.color: Qt.alpha(_primary, 0.15)
    border.width: 0
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.alpha(_primary, 0.15)
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 0

    // ── LEFT: Workspaces + Window ──────────────────────
    RowLayout {
      spacing: 0
      Layout.alignment: Qt.AlignVCenter

      // Workspaces pill
      Rectangle {
        color: Qt.alpha(_surface, 0.3)
        border.color: Qt.alpha(_primary, 0.1)
        border.width: 1
        radius: 10
        height: 28
        implicitWidth: 130

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 4
          anchors.rightMargin: 4
          spacing: 1

          Repeater {
            model: 5

            Rectangle {
              id: wsBtn
              required property int index
        property var ws: Hyprland.workspaces.values.find(function(w) { return w.id === index + 1 })
        property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === index + 1 : false

              width: 20
              height: 22
              radius: 7
              color: isActive ? _primary : "transparent"

              Text {
                anchors.centerIn: parent
                text: index + 1
                color: isActive ? _bg : (ws ? _fg : Qt.alpha(_fg, 0.3))
                font.pixelSize: 11
                font.bold: isActive
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (!isActive) parent.color = Qt.alpha(_primary, 0.15)
                onExited: if (!isActive) parent.color = "transparent"
                onClicked: {
                  var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
                  p.command = ["hyprctl", "dispatch", "workspace", String(index + 1)]
                  p.running = true
                }
              }
            }
          }
        }
      }

      // Window title
      Text {
        id: windowTitle
        text: {
          var win = Hyprland.focusedWindow
          if (!win) return ""
          var title = win.title
          if (!title || title === "") return ""
          return title.length > 40 ? title.substring(0, 38) + ".." : title
        }
        color: _fg
        font.pixelSize: 11
        elide: Text.ElideRight
        visible: text.length > 0
        Layout.leftMargin: 8
        Layout.preferredWidth: 200
        Layout.maximumWidth: 250
      }
    }

    Item { Layout.fillWidth: true }

    // ── CENTER: Clock ──────────────────────────────────
    Text {
      id: clock
      text: Qt.formatDateTime(new Date(), "ddd MMM dd - HH:mm")
      color: _fg
      font.pixelSize: 11
      font.bold: true
      Layout.alignment: Qt.AlignCenter

      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd MMM dd - HH:mm")
      }
    }

    Item { Layout.fillWidth: true }

    // ── RIGHT: Modules ─────────────────────────────────
    RowLayout {
      spacing: 3
      Layout.alignment: Qt.AlignVCenter

      // Bluetooth
      Rectangle {
        id: btModule
        visible: Bluetooth.adapters.length > 0 && Bluetooth.adapters[0].powered
        height: 28
        width: 32
        radius: 10
        color: mA_bt.containsMouse ? Qt.alpha(_primary, 0.2) : Qt.alpha(_surface, 0.4)
        border.color: mA_bt.containsMouse ? Qt.alpha(_primary, 0.3) : Qt.alpha(_primary, 0.1)
        border.width: 1

        property bool hasConnected: {
          for (var i = 0; i < Bluetooth.adapters.length; i++) {
            if (Bluetooth.adapters.get(i).connectedDevices.length > 0) return true
          }
          return false
        }

        Text {
          anchors.centerIn: parent
          text: btModule.hasConnected ? "󰂯" : "󰂲"
          color: btModule.hasConnected ? _primary : _muted
          font.pixelSize: 12
        }

        // ── Tooltip element (floats above module) ──
        Rectangle {
          id: btTooltip
          anchors.bottom: parent.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          height: 20
          width: btTooltipText.width + 12
          radius: 4
          color: Qt.alpha(_surface, 0.9)
          border.color: Qt.alpha(_primary, 0.2)
          border.width: 1
          visible: mA_bt.containsMouse

          Text {
            id: btTooltipText
            anchors.centerIn: parent
            text: {
              if (btModule.hasConnected) {
                var names = []
                for (var i = 0; i < Bluetooth.adapters.length; i++) {
                  var devs = Bluetooth.adapters.get(i).connectedDevices
                  for (var j = 0; j < devs.length; j++)
                    names.push(devs.get(j).name)
                }
                return names.join(", ")
              }
              return Bluetooth.adapters[0] && Bluetooth.adapters[0].powered ? "No devices" : "Bluetooth off"
            }
            color: _fg
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: mA_bt
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["/home/jllyn/.config/rofi/scripts/bluetooth-manager"]
              p.running = true
            } else {
              var a = Bluetooth.adapters[0]
              if (a) a.powered = !a.powered
            }
          }
        }
      }

      // Network
      Rectangle {
        id: netModule
        height: 28
        width: 32
        radius: 10
        color: mA_net.containsMouse ? Qt.alpha(_primary, 0.2) : Qt.alpha(_surface, 0.4)
        border.color: mA_net.containsMouse ? Qt.alpha(_primary, 0.3) : Qt.alpha(_primary, 0.1)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: networkConnected ? "󰤨" : "󰤭"
          color: networkConnected ? _fg : _muted
          font.pixelSize: 12
        }

        Rectangle {
          id: netTooltip
          anchors.bottom: parent.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          height: 20
          width: netTooltipText.width + 12
          radius: 4
          color: Qt.alpha(_surface, 0.9)
          border.color: Qt.alpha(_primary, 0.2)
          border.width: 1
          visible: mA_net.containsMouse

          Text {
            id: netTooltipText
            anchors.centerIn: parent
            text: networkConnected ? networkSsid : "Disconnected"
            color: _fg
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: mA_net
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["nm-connection-editor"]
              p.running = true
            } else {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["qs", "-p", "/home/jllyn/.config/quickshell/wifi.qml"]
              p.running = true
            }
          }
        }
      }

      Process {
        id: netProc
        command: ["nmcli", "-g", "ACTIVE,SSID", "d", "w"]
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: SplitParser {
          onRead: function(data) {
            if (!data) return
            var parts = data.split(":")
            if (parts.length >= 2) {
              root.networkConnected = parts[0] === "yes"
              root.networkSsid = parts[1]
            }
          }
        }
      }

      // PulseAudio
      Rectangle {
        id: audioModule
        height: 28
        width: 52
        radius: 10
        color: mA_audio.containsMouse ? Qt.alpha(_primary, 0.2) : Qt.alpha(_surface, 0.4)
        border.color: mA_audio.containsMouse ? Qt.alpha(_primary, 0.3) : Qt.alpha(_primary, 0.1)
        border.width: 1

        property var sink: Pipewire.defaultAudioSink
        property int vol: sink ? Math.round(sink.volume * 100) : 0
        property bool muted: sink && sink.mute !== undefined ? sink.mute : false

        RowLayout {
          anchors.centerIn: parent
          spacing: 3

          Text {
            text: audioModule.muted ? "󰝟" : (audioModule.vol > 50 ? "󰕾" : audioModule.vol > 0 ? "󰖀" : "󰕿")
            color: audioModule.muted ? _muted : _fg
            font.pixelSize: 12
          }

          Text {
            text: audioModule.muted ? "M" : audioModule.vol + "%"
            color: audioModule.muted ? _muted : Qt.alpha(_fg, 0.7)
            font.pixelSize: 10
            visible: audioModule.vol > 0 || audioModule.muted
          }
        }

        MouseArea {
          id: mA_audio
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["pavucontrol"]
              p.running = true
            } else if (Pipewire.defaultAudioSink) {
              Pipewire.defaultAudioSink.mute = !Pipewire.defaultAudioSink.mute
            }
          }
          onWheel: (wheel) => {
            if (!Pipewire.defaultAudioSink) return
            var step = 0.05
            var newVol = Pipewire.defaultAudioSink.volume + (wheel.angleDelta.y > 0 ? step : -step)
            Pipewire.defaultAudioSink.volume = Math.max(0, Math.min(1, newVol))
          }
        }
      }

      // Battery
      Rectangle {
        id: battModule
        height: 28
        width: 32
        radius: 10
        color: mA_batt.containsMouse ? Qt.alpha(_primary, 0.2) : Qt.alpha(_surface, 0.4)
        border.color: {
          if (mA_batt.containsMouse) return Qt.alpha(_primary, 0.3)
          if (battModule.battCritical) return _error
          if (battModule.battWarning) return _warning
          if (battModule.charging) return Qt.alpha("#a6e3a1", 0.4)
          return Qt.alpha(_primary, 0.1)
        }
        border.width: 1
        visible: device !== null

        property var device: {
          var devs = UPower.devices
          for (var i = 0; i < devs.count; i++) {
            if (devs.get(i).type === UPowerDeviceType.Battery) return devs.get(i)
          }
          return null
        }
        property int pct: device ? Math.round(device.percentage) : 0
        property bool charging: device ? device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged : false
        property bool battWarning: !charging && pct <= 20
        property bool battCritical: !charging && pct <= 10

        Text {
          anchors.centerIn: parent
          text: {
            if (battModule.charging && battModule.pct >= 100) return "󰂄"
            if (battModule.charging) return "󰂄"
            if (battModule.pct >= 90) return "󰁹"
            if (battModule.pct >= 80) return "󰂂"
            if (battModule.pct >= 70) return "󰂁"
            if (battModule.pct >= 60) return "󰂀"
            if (battModule.pct >= 50) return "󰁿"
            if (battModule.pct >= 40) return "󰁾"
            if (battModule.pct >= 30) return "󰁽"
            if (battModule.pct >= 20) return "󰁼"
            if (battModule.pct >= 10) return "󰁻"
            return "󰁺"
          }
          color: battModule.battCritical ? _error : battModule.battWarning ? _warning : (battModule.charging ? "#a6e3a1" : _fg)
          font.pixelSize: 12
        }

        Rectangle {
          id: battTooltip
          anchors.bottom: parent.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          height: 20
          width: battTooltipText.width + 12
          radius: 4
          color: Qt.alpha(_surface, 0.9)
          border.color: Qt.alpha(_primary, 0.2)
          border.width: 1
          visible: mA_batt.containsMouse && battModule.device

          Text {
            id: battTooltipText
            anchors.centerIn: parent
            text: {
              var d = battModule.device
              if (!d) return ""
              var txt = battModule.pct + "%"
              if (battModule.charging) txt += " (charging)"
              if (d.timeToFull > 0 && battModule.charging) txt += " - " + Math.round(d.timeToFull) + "m to full"
              if (d.timeToEmpty > 0 && !battModule.charging) txt += " - " + Math.round(d.timeToEmpty) + "m remaining"
              return txt
            }
            color: _fg
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: mA_batt
          anchors.fill: parent
          hoverEnabled: true
        }
      }

      // System Tray
      Rectangle {
        id: trayModule
        height: 28
        implicitWidth: trayRepeater.count * 24 + 8
        radius: 10
        color: Qt.alpha(_surface, 0.4)
        border.color: Qt.alpha(_primary, 0.1)
        border.width: 1
        visible: trayRepeater.count > 0

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 4
          anchors.rightMargin: 4
          spacing: 2

          Repeater {
            id: trayRepeater
            model: SystemTray.items

            Item {
              required property var modelData
              width: 20
              height: 20

              Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: modelData.icon
                asynchronous: true
                sourceSize.width: 16
                sourceSize.height: 16
                visible: status === Image.Ready
              }

              Text {
                anchors.centerIn: parent
                text: modelData.title ? modelData.title.charAt(0).toUpperCase() : "?"
                color: _fg
                font.pixelSize: 10
                visible: parent.children[0].status !== Image.Ready
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (modelData.menu && modelData.hasMenu)
                    modelData.menu.popup()
                  else
                    modelData.activate()
                }
              }
            }
          }
        }
      }

      // Swaync
      Rectangle {
        id: notifModule
        height: 28
        width: 32
        radius: 10
        color: mA_notif.containsMouse ? Qt.alpha(_primary, 0.2) : Qt.alpha(_surface, 0.4)
        border.color: mA_notif.containsMouse ? Qt.alpha(_primary, 0.3) : Qt.alpha(_primary, 0.1)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: {
            if (dnd) return "󰂛"
            if (notificationCount > 0) return "󰂚"
            return "󰂜"
          }
          color: dnd ? _muted : (notificationCount > 0 ? _primary : _fg)
          font.pixelSize: 12
        }

        Rectangle {
          id: notifTooltip
          anchors.bottom: parent.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          height: 20
          width: notifTooltipText.width + 12
          radius: 4
          color: Qt.alpha(_surface, 0.9)
          border.color: Qt.alpha(_primary, 0.2)
          border.width: 1
          visible: mA_notif.containsMouse

          Text {
            id: notifTooltipText
            anchors.centerIn: parent
            text: dnd ? "Do Not Disturb" : (notificationCount > 0 ? notificationCount + " notification(s)" : "No notifications")
            color: _fg
            font.pixelSize: 9
          }
        }

        MouseArea {
          id: mA_notif
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["swaync-client", "--toggle-dnd"]
              p.running = true
            } else {
              var p = Qt.createQmlObject("import Quickshell.Io; Process {}", root)
              p.command = ["swaync-client", "--toggle-panel"]
              p.running = true
            }
          }
        }
      }
    }
  }

  // ── Periodic Network Poll ──────────────────────────────
  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: netProc.running = true
  }
  Component.onCompleted: netProc.running = true

  // ── Swaync Listener ────────────────────────────────────
  Process {
    id: swayncSub
    running: true
    command: ["swaync-client", "--subscribe-waybar"]
    stdout: SplitParser {
      onRead: function(data) {
        if (!data) return
        try {
          var j = JSON.parse(data)
          if (j.hasOwnProperty("count")) root.notificationCount = j.count
          if (j.hasOwnProperty("dnd")) root.dnd = j.dnd
        } catch (e) {}
      }
    }
  }
}
