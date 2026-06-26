import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string cardTitle: ""
    property bool active: false
    property string currentProfile: "balanced"
    property int currentBrightness: 80
    property int currentKbd: 50
    readonly property var profileButtons: [{
        "label": "Saver",
        "val": "power-saver"
    }, {
        "label": "Bal",
        "val": "balanced"
    }, {
        "label": "Perf",
        "val": "performance"
    }]

    signal profileChanged(string profile)
    signal brightnessChanged(int pct)
    signal kbdChanged(int pct)

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 16
    color: root.active ? Theme.primaryAlpha008 : Theme.surface
    border.width: 1
    border.color: root.active ? Theme.primaryAlpha03 : Theme.surfaceLighter

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.cardTitle
                color: root.active ? Theme.primary : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.active ? "\u25cf Active" : ""
                color: Theme.green
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
                visible: root.active
            }

        }

        // ── Profile selector row ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Profile:"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
                Layout.minimumWidth: 48
            }

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: root.profileButtons

                delegate: Rectangle {
                    required property var modelData

                    Layout.preferredWidth: 52
                    height: 28
                    color: modelData.val === root.currentProfile ? Theme.primary : Theme.surfaceLighter

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: modelData.val === root.currentProfile ? Theme.bg : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: modelData.val === root.currentProfile
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.profileChanged(modelData.val)
                    }

                }

            }

        }

        // ── Screen brightness slider ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\u2600"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
            }

            Item {
                Layout.fillWidth: true
                height: 24

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 0
                    color: Theme.surfaceLighter

                    Rectangle {
                        width: parent.width * (root.currentBrightness / 100)
                        height: parent.height
                        radius: 0
                        color: root.active ? Theme.primary : Theme.muted
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pct = Math.round((mouseX / width) * 100);
                        pct = Math.max(0, Math.min(100, pct));
                        root.brightnessChanged(pct);
                    }
                }

            }

            Text {
                text: root.currentBrightness + "%"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }

        }

        // ── Keyboard backlight slider ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\u2328"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
            }

            Item {
                Layout.fillWidth: true
                height: 24

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 0
                    color: Theme.surfaceLighter

                    Rectangle {
                        width: parent.width * (root.currentKbd / 100)
                        height: parent.height
                        radius: 0
                        color: root.active ? Theme.primary : Theme.muted
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pct = Math.round((mouseX / width) * 100);
                        pct = Math.max(0, Math.min(100, pct));
                        root.kbdChanged(pct);
                    }
                }

            }

            Text {
                text: root.currentKbd + "%"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }

        }

    }

}
