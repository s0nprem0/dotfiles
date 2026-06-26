import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Controls

PopupPanel {
    id: root

    property var ports: []
    property bool loading: false
    property string errorMsg: ""

    function refreshPorts() {
        root.loading = true;
        root.errorMsg = "";
        portsProc.running = true;
    }

    function killProcess(pid) {
        killProc.command = ["kill", "-15", pid.toString()];
        killProc.running = true;
    }

    anchorSide: "right"
    panelWidth: 420
    initialOffset: -420
    finalInset: 32
    introDuration: 120
    exitDuration: 100
    onBeforeOpen: root.refreshPorts()
    onBeforeClose: {
        root.errorMsg = "";
    }

    Process {
        id: portsProc

        command: [Theme.bin("ports_menu"), "--json"]
        environment: ({ "LANG": "C", "LC_ALL": "C" })

        onExited: function(code) {
            root.loading = false;
            if (code !== 0) {
                root.errorMsg = "ports_menu exited with code " + code;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim();
                if (!text) {
                    root.loading = false;
                    return;
                }
                try {
                    var data = JSON.parse(text);
                    root.ports = data.ports ?? [];
                } catch (e) {
                    root.errorMsg = "Parse error";
                    root.loading = false;
                }
            }
        }
    }

    Process {
        id: killProc

        onExited: function(code) {
            if (code !== 0) {
                root.errorMsg = "Kill failed with code " + code;
            }
            root.refreshPorts();
        }
    }

    contentComponent: Component {
        Item {
            anchors.fill: parent
            implicitWidth: mainLayout.implicitWidth
            implicitHeight: mainLayout.implicitHeight

            Column {
                id: mainLayout

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                // Header
                Text {
                    text: "Listening Ports"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.15
                }

                // Loading
                Text {
                    visible: root.loading
                    text: "Scanning ports…"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                }

                // Error
                Text {
                    visible: root.errorMsg !== ""
                    text: root.errorMsg
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                }

                // Empty
                Text {
                    visible: !root.loading && root.errorMsg === "" && root.ports.length === 0
                    text: "No listening ports found"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                }

                // Column Headers
                Rectangle {
                    visible: root.ports.length > 0 && !root.loading
                    width: parent.width
                    height: 24
                    color: Theme.surface

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6

                        Text {
                            width: 50
                            text: "Protocol"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: 50
                            text: "Port"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: 120
                            text: "Process"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: 50
                            text: "PID"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: 28
                            text: ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Port List
                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, 500)
                    model: root.ports
                    interactive: true
                    clip: true

                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        color: index % 2 === 0 ? "transparent" : Qt.alpha(Theme.primary, 0.04)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6

                            Text {
                                width: 50
                                text: modelData.protocol
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: 50
                                text: modelData.port
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: 120
                                text: modelData.process
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            Text {
                                width: 50
                                text: modelData.pid
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 48
                                height: 28
                                color: index % 2 === 0 ? Qt.alpha(Theme.error, 0.08) : Qt.alpha(Theme.error, 0.12)
                                radius: 0
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Kill"
                                    color: Theme.error
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.color = Qt.alpha(Theme.error, 0.2)
                                    onExited: parent.color = index % 2 === 0 ? Qt.alpha(Theme.error, 0.08) : Qt.alpha(Theme.error, 0.12)
                                    onClicked: root.killProcess(modelData.pid)
                                }
                            }
                        }
                    }
                }

                // Footer
                Row {
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Refresh"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshPorts()
                        }
                    }

                    Text {
                        text: "Close"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePopup()
                        }
                    }
                }
            }
        }
    }
}
