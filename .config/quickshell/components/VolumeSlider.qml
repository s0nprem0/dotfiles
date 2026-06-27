import "../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property double currentValue: 0
    property bool muted: false
    property bool enabled: true
    property string label: ""
    property real maxWidth: 200

    signal valueChanged(double value)
    signal muteToggled(bool muted)

    implicitWidth: label.length > 0 ? Math.max(120, childrenRect.width) : maxWidth
    implicitHeight: 24
    focus: true
    Keys.onPressed: function(event) {
        if (!enabled)
            return ;

        if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
            root.valueChanged(Math.min(1, root.currentValue + 0.05));
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus) {
            root.valueChanged(Math.max(0, root.currentValue - 0.05));
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            root.muteToggled(!root.muted);
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        RowLayout {
            width: parent.width
            height: 16
            enabled: root.enabled

            Text {
                text: root.label
                color: Theme.primary
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: root.muted ? "Muted" : Math.round(root.currentValue * 100) + "%"
                color: root.muted ? Theme.muted : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }

        }

        Item {
            width: parent.width
            height: 5
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                color: Theme.surface

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: parent.width * Math.min(1, root.currentValue)
                    color: Theme.primary
                }

            }

            MouseArea {
                anchors.fill: parent
                enabled: root.enabled
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    var v = Math.max(0, Math.min(1, mouse.x / width));
                    root.valueChanged(v);
                }
                onPositionChanged: {
                    if (pressed) {
                        var v = Math.max(0, Math.min(1, mouse.x / width));
                        if (Math.abs(v - root.currentValue) > 0.02)
                            root.valueChanged(v);

                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    var delta = event.angleDelta.y / 120;
                    var newVol = Math.max(0, Math.min(1, root.currentValue + delta * 0.05));
                    root.valueChanged(newVol);
                }
            }

        }

    }

}
