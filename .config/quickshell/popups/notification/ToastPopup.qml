import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../service"

Item {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: toastPopup
                required property var modelData
                visible: toastRepeater.count > 0

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: false

                implicitWidth: 380
                implicitHeight: Math.min(toastColumn.implicitHeight + 16, 400)

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: 40
                    right: 8
                }

                function urgencyColor(urgency) {
                    if (urgency === 2) return Theme.error;
                    if (urgency === 1) return Theme.primary;
                    return Theme.muted;
                }

                Column {
                    id: toastColumn
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Repeater {
                        id: toastRepeater
                        model: NotificationState.toastModel

                        delegate: Item {
                            id: toastDelegate
                            width: toastColumn.width - 8
                            height: toastCard.height
                            anchors.horizontalCenter: parent.horizontalCenter

                            property real opacityValue: 0
                            property real scaleValue: 0.8
                            property bool closing: false
                            property bool hovered: false

                            Component.onCompleted: {
                                opacityValue = 1
                                scaleValue = 1
                            }

                            Behavior on opacityValue {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Behavior on scaleValue {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            function close() {
                                if (closing) return
                                closing = true
                                opacityValue = 0
                                scaleValue = 0.8
                                dismissTimer.stop()
                                closeTimer.start()
                            }

                            function autoClose() {
                                if (closing) return
                                closing = true
                                opacityValue = 0
                                scaleValue = 0.8
                                dismissTimer.stop()
                                softCloseTimer.start()
                            }

                            function invokeDefault() {
                                if (closing) return
                                var nd = model.notifData
                                if (nd && nd.notification) {
                                    if (nd.notification.defaultAction)
                                        nd.notification.defaultAction.invoke()
                                    else if (nd.actions && nd.actions.length > 0)
                                        nd.actions[0].invoke()
                                }
                                close()
                            }

                            Timer {
                                id: closeTimer
                                interval: 200
                                onTriggered: {
                                    if (NotificationState.service)
                                        NotificationState.service.dismissToastById(model.notifId)
                                }
                            }

                            Timer {
                                id: softCloseTimer
                                interval: 200
                                onTriggered: {
                                    if (NotificationState.service)
                                        NotificationState.service.softDismissToastById(model.notifId)
                                }
                            }

                            Timer {
                                id: dismissTimer
                                interval: model.expireTimeout > 0
                                    ? Math.min(model.expireTimeout, 8000)
                                    : model.urgency === 2 ? 8000 : 6000
                                running: !toastDelegate.hovered
                                onTriggered: autoClose()
                            }

                            Rectangle {
                                id: toastCard
                                width: parent.width
                                height: mainLayout.implicitHeight + 20
                                radius: 8
                                color: Theme.surface
                                border.color: borderColor
                                border.width: 1
                                clip: true
                                opacity: toastDelegate.opacityValue
                                scale: toastDelegate.scaleValue
                                transformOrigin: Item.Right

                                readonly property int urg: model.urgency
                                readonly property color borderColor: Qt.alpha(urgencyColor(toastCard.urg), 0.4)

                                HoverHandler {
                                    onHoveredChanged: toastDelegate.hovered = hovered
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    radius: 2
                                    color: urgencyColor(toastCard.urg)
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    anchors.leftMargin: 3
                                }

                                RowLayout {
                                    id: mainLayout
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Image {
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 80
                                        fillMode: Image.PreserveAspectCrop
                                        clip: true
                                        source: model.notifData && model.notifData.image
                                            ? (model.notifData.image.startsWith("/") ? ("file://" + model.notifData.image) : model.notifData.image)
                                            : ""
                                        visible: model.notifData && model.notifData.image && model.notifData.image.length > 0
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    width: 16; height: 16
                                                    radius: 3
                                                    color: "transparent"
                                                    visible: model.appIcon && model.appIcon.length > 0
                                                    Image {
                                                        anchors.fill: parent
                                                        source: model.appIcon ? "image://icon/" + model.appIcon : ""
                                                        fillMode: Image.PreserveAspectFit
                                                    }
                                                }

                                                Text {
                                                    visible: !model.appIcon || model.appIcon.length === 0
                                                    text: {
                                                        var name = (model.appName || "").toLowerCase()
                                                        if (model.urgency === 2) return "󰀦"
                                                        if (name.includes("discord")) return "󰙯"
                                                        if (name.includes("firefox")) return "󰈹"
                                                        if (name.includes("spotify")) return "󰓇"
                                                        if (name.includes("telegram")) return ""
                                                        if (name.includes("whatsapp")) return "󰖣"
                                                        if (name.includes("signal")) return "󰋽"
                                                        if (name.includes("slack")) return "󰒱"
                                                        return "󰂚"
                                                    }
                                                    color: toastPopup.urgencyColor(model.urgency)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                Text {
                                                    text: model.appName || "Notification"
                                                    color: Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }

                                            Rectangle {
                                                visible: (model.groupCount || 1) > 1
                                                height: 16
                                                width: groupLabel.implicitWidth + 8
                                                radius: 8
                                                color: Qt.alpha(Theme.primary, 0.2)
                                                Layout.alignment: Qt.AlignRight

                                                Text {
                                                    id: groupLabel
                                                    anchors.centerIn: parent
                                                    text: "+" + ((model.groupCount || 1) - 1)
                                                    color: Theme.primary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: closeMa.containsMouse ? Qt.alpha(Theme.muted, 0.2) : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                }

                                                MouseArea {
                                                    id: closeMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: close()
                                                }
                                            }
                                        }

                                        Text {
                                            text: model.summary
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: model.body
                                            color: Qt.alpha(Theme.fg, 0.7)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            textFormat: Text.StyledText
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            visible: text.length > 0
                                            Layout.fillWidth: true
                                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                                        }

                                        // ── Action buttons ─────────────────────────
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            visible: model.notifData && model.notifData.actions && model.notifData.actions.length > 0

                                            Repeater {
                                                model: model.notifData && model.notifData.actions || []
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    implicitHeight: 22
                                                    implicitWidth: actLabel.implicitWidth + 10
                                                    color: actMa.containsMouse ? Qt.alpha(Theme.primary, 0.2) : Theme.surfaceLighter
                                                    radius: 4
                                                    border.width: 1
                                                    border.color: actMa.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.15)

                                                    Text {
                                                        id: actLabel
                                                        anchors.centerIn: parent
                                                        text: modelData.label || "unknown"
                                                        color: Theme.fg
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 9
                                                    }

                                                    MouseArea {
                                                        id: actMa
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            modelData.invoke()
                                                            close()
                                                        }
                                                    }
                                                }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "Dismiss"
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: autoClose()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 2
                                        radius: 1
                                        color: Theme.surfaceLighter
                                        Layout.topMargin: 4
                                        visible: model.urgency !== 2

                                        Rectangle {
                                            id: progressBar
                                            height: parent.height
                                            width: parent.width
                                            radius: 1
                                            color: toastPopup.urgencyColor(model.urgency)
                                            opacity: 0.6

                                            SequentialAnimation {
                                                running: model.urgency !== 2
                                                PauseAnimation { duration: 50 }
                                                NumberAnimation {
                                                    target: progressBar
                                                    property: "width"
                                                    to: 0
                                                    duration: model.expireTimeout > 0
                                                        ? Math.min(model.expireTimeout, 8000)
                                                        : model.urgency === 2 ? 8000 : 6000
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                                MouseArea {
                                    id: toastMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onEntered: toastCard.color = Qt.lighter(Theme.surface, 1.04)
                                    onExited: toastCard.color = Theme.surface
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton && !closing)
                                            invokeDefault()
                                        else if (mouse.button === Qt.RightButton)
                                            close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
