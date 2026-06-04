import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

FloatingWindow {
  id: window
  implicitWidth: 380
  implicitHeight: 460
  visible: true
  color: "transparent"

  // ── Catppuccin Macchiato ───────────────────────────────
  readonly property color _base: "#24273A"
  readonly property color _surface0: "#363A4F"
  readonly property color _overlay0: "#6E738D"
  readonly property color _surface1: "#494D64"
  readonly property color _text: "#CAD3F5"
  readonly property color _green: "#A6DA95"
  readonly property color _yellow: "#EED49F"
  readonly property color _red: "#ED8796"
  readonly property color _blue: "#8AADF4"

  // ── State ──────────────────────────────────────────────
  property var networkList: []
  property var savedSsids: []
  property string activeSsid: ""
  property bool wifiEnabled: true
  property bool scanning: false
  property string pendingSsid: ""
  property bool connecting: false

  function signalIcon(s) {
    if (s >= 80) return "󰤨"
    if (s >= 60) return "󰤥"
    if (s >= 40) return "󰤢"
    if (s >= 20) return "󰤟"
    return "󰤫"
  }

  // Split on : but respect \: escape sequences
  function splitFields(line) {
    var fields = []
    var current = ""
    var i = 0
    while (i < line.length) {
      if (line[i] === "\\" && i + 1 < line.length && line[i + 1] === ":") {
        current += ":"
        i += 2
      } else if (line[i] === ":") {
        fields.push(current)
        current = ""
        i++
      } else {
        current += line[i]
        i++
      }
    }
    fields.push(current)
    return fields
  }

  function parseNetworks(text, saved) {
    var list = []
    var lines = text.trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = splitFields(lines[i])
      if (parts.length < 6) continue
      var ssid = parts[3]
      if (!ssid) continue
      var active = parts[0] === "yes"
      var signal = parseInt(parts[1])
      list.push({ ssid: ssid, signal: signal, active: active, saved: saved.indexOf(ssid) >= 0 })
    }
    // Deduplicate by SSID, keep highest signal
    var map = {}
    for (var j = 0; j < list.length; j++) {
      var n = list[j]
      if (!map[n.ssid] || n.signal > map[n.ssid].signal || n.active)
        map[n.ssid] = n
    }
    var result = []
    for (var key in map) result.push(map[key])
    result.sort(function(a, b) {
      if (a.active && !b.active) return -1
      if (!a.active && b.active) return 1
      return b.signal - a.signal
    })
    activeSsid = result.length > 0 && result[0].active ? result[0].ssid : ""
    return result
  }

  function fetchSaved() {
    savedProc.running = false
    savedProc.command = ["nmcli", "-g", "NAME", "connection", "show"]
    savedProc.running = true
  }

  function doScan() {
    scanProc.running = false
    scanProc.command = ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
    scanProc.running = true
  }

  function scanWifi() {
    if (scanning) return
    scanning = true
    fetchSaved()
  }

  function toggleWifi() {
    toggleProc.running = false
    toggleProc.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]
    toggleProc.running = true
  }

  function connectToNetwork(ssid) {
    if (ssid === activeSsid || connecting) return
    connecting = true
    pendingSsid = ""
    connectProc.usePassword = false
    connectProc.running = false
    connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
    connectProc.running = true
  }

  function submitPassword() {
    var pwd = pwdInput.text
    if (!pwd || !pendingSsid) return
    connecting = true
    connectProc.usePassword = true
    connectProc.running = false
    connectProc.command = ["nmcli", "dev", "wifi", "connect", pendingSsid, "password", pwd]
    connectProc.running = true
    pwdDialog.visible = false
    pwdInput.text = ""
  }

  function disconnectWifi() {
    if (!activeSsid) return
    disconnectProc.running = false
    disconnectProc.command = ["nmcli", "connection", "down", "id", activeSsid]
    disconnectProc.running = true
  }

  // ── Saved Connections Process ──────────────────────────
  // Runs before scan to populate savedSsids
  Process {
    id: savedProc
    environment: ({ LANG: "C", LC_ALL: "C" })
    stdout: StdioCollector {
      onStreamFinished: function() {
        savedSsids = savedProc.stdout.text.trim().split("\n").filter(function(s) { return !!s })
        doScan()
      }
    }
  }

  // ── Scan Process ───────────────────────────────────────
  Process {
    id: scanProc
    environment: ({ LANG: "C", LC_ALL: "C" })
    stdout: StdioCollector {
      onStreamFinished: {
        networkList = parseNetworks(scanProc.stdout.text, savedSsids)
        scanning = false
      }
    }
  }

  // ── Connect Process ────────────────────────────────────
  Process {
    id: connectProc
    property bool usePassword: false
    environment: ({ LANG: "C", LC_ALL: "C" })
    stderr: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      connecting = false
      if (exitCode !== 0 && !usePassword) {
        var err = stderr.text
        if (err.includes("Secrets were required") || err.includes("password")) {
          pendingSsid = command[command.length - 1]
          if (pendingSsid) {
            pwdDialog.visible = true
            pwdInput.forceActiveFocus()
          }
        }
      }
      scanWifi()
    }
  }

  // ── Disconnect Process ─────────────────────────────────
  Process {
    id: disconnectProc
    stdout: SplitParser { onRead: scanWifi() }
  }

  // ── Toggle Process ─────────────────────────────────────
  Process {
    id: toggleProc
    stdout: SplitParser { onRead: scanWifi() }
  }

  // ── nmcli monitor (reactive on changes) ────────────────
  Process {
    id: subscriber
    running: true
    command: ["nmcli", "monitor"]
    stdout: SplitParser { onRead: scanWifi() }
  }

  // ── Initial Scan + Timer ───────────────────────────────
  Component.onCompleted: scanWifi()

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: scanWifi()
  }

  // ── Background ─────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color: _base
    radius: 12
    border.color: _surface1
    border.width: 1
    clip: true

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // ── Header ─────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        color: _surface0

        Item {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            color: _text
            font.pixelSize: 15
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅖"
            color: _overlay0
            font.pixelSize: 16
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
          }
        }
      }

      // ── Status ─────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        color: "transparent"

        Item {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: connecting
              ? "󱚼  Connecting..."
              : activeSsid
                ? "󰤨  " + activeSsid
                : "󰤭  Disconnected"
            color: activeSsid ? _text : _overlay0
            font.pixelSize: 11
            elide: Text.ElideRight
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: _surface1
      }

      // ── Network List ───────────────────────────────────
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
          id: listView
          anchors.fill: parent
          anchors.margins: 4
          spacing: 1
          model: networkList

          delegate: Rectangle {
            width: listView.width - 8
            height: 42
            radius: 8
            color: modelData.active ? _surface0 : (mA.containsMouse ? _surface0 : "transparent")

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              Text {
                text: signalIcon(modelData.signal)
                color: modelData.active ? _green : _text
                font.pixelSize: 16
                Layout.preferredWidth: 22
              }

              ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                RowLayout {
                  spacing: 4
                  Layout.fillWidth: true

                  Text {
                    text: modelData.ssid
                    color: _text
                    font.pixelSize: 12
                    font.bold: modelData.active
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    visible: modelData.saved && !modelData.active
                    text: "󰌉"
                    color: _yellow
                    font.pixelSize: 10
                  }
                }

                Text {
                  text: modelData.active ? "Connected" : modelData.saved ? "Saved" : ""
                  color: modelData.active ? _green : _overlay0
                  font.pixelSize: 10
                }
              }

              Text {
                text: modelData.signal + "%"
                color: _overlay0
                font.pixelSize: 10
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
              }
            }

            MouseArea {
              id: mA
              anchors.fill: parent
              hoverEnabled: true
              onClicked: connectToNetwork(modelData.ssid)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: networkList.length === 0 && !scanning
          text: "󰤭  No networks found"
          color: _overlay0
          font.pixelSize: 13
        }

        Text {
          anchors.centerIn: parent
          visible: scanning && networkList.length === 0
          text: "󰔄  Scanning..."
          color: _overlay0
          font.pixelSize: 13
        }
      }

      // ── Footer ─────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        color: _surface0

        Item {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14

          RowLayout {
            anchors.fill: parent
            spacing: 12

            Text {
              visible: !!activeSsid
              text: "󰤨  Disconnect"
              color: _red
              font.pixelSize: 11
              MouseArea { anchors.fill: parent; onClicked: disconnectWifi() }
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "󰖪  Turn Off"
              color: _blue
              font.pixelSize: 11
              MouseArea { anchors.fill: parent; onClicked: toggleWifi() }
            }

            Text {
              text: "󰒅  Refresh"
              color: _overlay0
              font.pixelSize: 11
              MouseArea { anchors.fill: parent; onClicked: scanWifi() }
            }
          }
        }
      }
    }
  }

  // ── Password Dialog ────────────────────────────────────
  Rectangle {
    id: pwdDialog
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.7)
    visible: false
    radius: 12

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 48
      height: 140
      radius: 10
      color: _surface0
      border.color: _surface1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
          text: "Password for " + pendingSsid
          color: _text
          font.pixelSize: 13
          elide: Text.ElideRight
        }

        Rectangle {
          Layout.fillWidth: true
          height: 34
          color: _base
          radius: 6
          border.color: _surface1

          TextInput {
            id: pwdInput
            anchors.fill: parent
            anchors.margins: 8
            color: _text
            font.pixelSize: 13
            echoMode: TextInput.Password
            focus: true
            Keys.onReturnPressed: submitPassword()
            Keys.onEscapePressed: { pwdDialog.visible = false; pendingSsid = ""; text = "" }
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          spacing: 12

          Text {
            text: "Cancel"
            color: _overlay0
            font.pixelSize: 12
            MouseArea {
              anchors.fill: parent
              onClicked: { pwdDialog.visible = false; pendingSsid = ""; pwdInput.text = "" }
            }
          }

          Text {
            text: "Connect"
            color: _blue
            font.pixelSize: 12
            font.bold: true
            MouseArea { anchors.fill: parent; onClicked: submitPassword() }
          }
        }
      }
    }
  }

  // ── Close on Escape ────────────────────────────────────
  Item {
    focus: true
    Keys.onEscapePressed: Qt.quit()
    Component.onCompleted: forceActiveFocus()
  }
}
