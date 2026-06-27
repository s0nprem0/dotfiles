import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property int chargeLimit: 80
    property int screenBrightness: 80
    property int kbdBrightness: 50

    signal profileSelected(string profile)
    signal screenBrightnessUpdated(int pct)
    signal keyboardBrightnessUpdated(int pct)
    signal chargeLimitUpdated(int limit)

    Layout.fillWidth: true
    radius: 0
    color: Theme.surface
    border.width: 1
    border.color: Theme.primaryAlpha03
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Text {
            text: "Power"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize3xl
            font.bold: true
        }

        Text {
            text: "Power Mode"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [{
                    "label": "SAVER",
                    "profile": "power-saver"
                }, {
                    "label": "BALANCED",
                    "profile": "balanced"
                }, {
                    "label": "PERFORMANCE",
                    "profile": "performance"
                }]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    height: 40
                    color: root.activeProfile === modelData.profile ? Theme.primary : Theme.surfaceLighter
                    border.width: 1
                    border.color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.activeProfile === modelData.profile ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: root.activeProfile === modelData.profile
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.profileSelected(modelData.profile)
                    }

                }

            }

        }

        Separator {
            Layout.fillWidth: true
        }

        Text {
            text: "Screen Brightness"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf0e0"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
            }

            Rectangle {
                Layout.fillWidth: true
                height: 8
                color: Theme.surfaceLighter

                Rectangle {
                    width: parent.width * (root.screenBrightness / 100)
                    height: parent.height
                    color: Theme.primary
                }

            }

            Text {
                text: root.screenBrightness + "%"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round((mouseX / width) * 100);
                    pct = Math.max(0, Math.min(100, pct));
                    root.screenBrightnessUpdated(pct);
                }
            }

        }

        Separator {
            Layout.fillWidth: true
        }

        Text {
            text: "Keyboard Brightness"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf021"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
            }

            Rectangle {
                Layout.fillWidth: true
                height: 8
                color: Theme.surfaceLighter

                Rectangle {
                    width: parent.width * (root.kbdBrightness / 100)
                    height: parent.height
                    color: Theme.primary
                }

            }

            Text {
                text: root.kbdBrightness + "%"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round((mouseX / width) * 100);
                    pct = Math.max(0, Math.min(100, pct));
                    root.keyboardBrightnessUpdated(pct);
                }
            }

        }

        Separator {
            Layout.fillWidth: true
        }

        Text {
            text: "Battery Charge Limit"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf00e"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
            }

            Rectangle {
                Layout.fillWidth: true
                height: 8
                color: Theme.surfaceLighter

                Rectangle {
                    width: parent.width * (root.chargeLimit / 100)
                    height: parent.height
                    color: root.chargeLimit < 100 ? Theme.warning : Theme.primary
                }

            }

            Text {
                text: root.chargeLimit < 100 ? root.chargeLimit + "%" : "Full"
                color: root.chargeLimit < 100 ? Theme.primary : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.bold: root.chargeLimit < 100
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round((mouseX / width) * 100);
                    pct = Math.max(50, Math.min(100, pct));
                    root.chargeLimitUpdated(pct);
                }
            }

        }

    }

}
