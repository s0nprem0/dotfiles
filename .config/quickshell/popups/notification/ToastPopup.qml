import "."
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: toastPopup

                required property var modelData

                function urgencyColor(urgency) {
                    if (urgency === 2)
                        return Theme.error;
 // Critical
                    if (urgency === 1)
                        return Theme.primary;
 // Normal
                    return Theme.muted; // Low
                }

                visible: toastRepeater.count > 0
                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: false
                implicitWidth: 380
                implicitHeight: Math.min(toastColumn.implicitHeight + 16, Screen.height * 0.8)

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: 40
                    right: 16 // Added a bit more breathing room from the screen edge
                }

                Column {
                    id: toastColumn

                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2 // Mechanical, blocky gaps between toasts

                    Repeater {
                        id: toastRepeater

                        model: NotificationState.toastModel

                        delegate: Item {
                            id: toastDelegate

                            property real opacityValue: 0
                            property bool closing: false
                            property bool hovered: false

                            function close() {
                                if (closing)
                                    return ;

                                closing = true;
                                opacityValue = 0;
                                dismissTimer.stop();
                                softCloseTimer.start();
                            }

                            function hardClose() {
                                if (closing)
                                    return ;

                                closing = true;
                                opacityValue = 0;
                                dismissTimer.stop();
                                closeTimer.start();
                            }

                            function autoClose() {
                                if (closing)
                                    return ;

                                closing = true;
                                opacityValue = 0;
                                dismissTimer.stop();
                                softCloseTimer.start();
                            }

                            function invokeDefault() {
                                if (closing)
                                    return ;

                                var nd = model.notifData;
                                if (nd && nd.notification) {
                                    if (nd.notification.defaultAction)
                                        nd.notification.defaultAction.invoke();
                                    else if (nd.actions && nd.actions.length > 0)
                                        nd.actions[0].invoke();
                                }
                                hardClose();
                            }

                            width: toastColumn.width - 8
                            height: toastCard.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            Component.onCompleted: {
                                opacityValue = 1;
                            }

                            Timer {
                                id: closeTimer

                                interval: 50
                                onTriggered: {
                                    if (NotificationState.service) {
                                        NotificationState.service.dismissToastById(model.notifId);
                                    }
                                }
                            }

                            Timer {
                                id: softCloseTimer

                                interval: 50
                                onTriggered: {
                                    if (NotificationState.service) {
                                        NotificationState.service.softDismissToastById(model.notifId);
                                    }
                                }
                            }

                            Timer {
                                id: dismissTimer

                                interval: model.expireTimeout > 0 ? Math.min(model.expireTimeout, 8000) : (model.urgency === 2 ? 8000 : 6000)
                                running: !toastDelegate.hovered
                                onTriggered: autoClose()
                            }

                            // ── Brutalist Notification Card ──
                            Rectangle {
                                id: toastCard

                                readonly property int urg: model.urgency
                                readonly property color uColor: urgencyColor(urg)

                                z: 1
                                width: parent.width
                                height: mainLayout.implicitHeight
                                radius: 0
                                color: Theme.bg // High contrast background
                                border.color: uColor
                                border.width: 0
                                clip: true
                                opacity: toastDelegate.opacityValue

                                HoverHandler {
                                    onHoveredChanged: toastDelegate.hovered = hovered
                                }

                                ColumnLayout {
                                    id: mainLayout

                                    anchors.fill: parent
                                    spacing: 0

                                    // ── Row 1: Header Bar ──
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        color: toastDelegate.hovered ? Theme.surface : Theme.bg
                                        border.width: 0

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 1
                                            color: toastCard.uColor
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Text {
                                                text: model.urgency === 2 ? "󰀦" : (model.appIcon && model.appIcon.length === 0 ? IconResolver.nerdFontGlyph(model.appName) : "󰂚")
                                                color: toastCard.uColor
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                            }

                                            Text {
                                                text: (model.appName || "SYSTEM").toUpperCase()
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }

                                            // Sharp Close Button
                                            Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                radius: 0
                                                color: closeMa.containsMouse ? Theme.error : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: closeMa.containsMouse ? Theme.bg : Theme.muted
                                                    font.pixelSize: 10
                                                    font.bold: true
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

                                    }

                                    // ── Row 2: Content Body ──
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.margins: 12
                                        spacing: 12

                                        // Notification Image (if any)
                                        Rectangle {
                                            Layout.preferredWidth: 72
                                            Layout.preferredHeight: 72
                                            visible: model.notifData && model.notifData.image && model.notifData.image.length > 0
                                            color: "transparent"
                                            border.width: 1
                                            border.color: toastCard.uColor
                                            radius: 0

                                            Image {
                                                id: notifSrcImage

                                                anchors.fill: parent
                                                anchors.margins: 2
                                                fillMode: Image.PreserveAspectCrop
                                                clip: true
                                                source: model.notifData && model.notifData.image ? (model.notifData.image.startsWith("/") ? ("file://" + model.notifData.image) : model.notifData.image) : ""
                                                asynchronous: true
                                                cache: true
                                            }

                                        }

                                        // Text Block
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignTop
                                            spacing: 4

                                            Text {
                                                text: (model.summary || "").toUpperCase() // Force uppercase for summary
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
                                                text: model.body || ""
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                textFormat: Text.StyledText
                                                elide: Text.ElideRight
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                visible: text.length > 0
                                                Layout.fillWidth: true
                                                onLinkActivated: (link) => {
                                                    return Qt.openUrlExternally(link);
                                                }
                                            }

                                        }

                                    }

                                    // ── Row 3: Action Buttons ──
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        Layout.rightMargin: 12
                                        Layout.bottomMargin: 8
                                        spacing: 6
                                        visible: model.notifData && model.notifData.actions && model.notifData.actions.length > 0

                                        Repeater {
                                            model: model.notifData && model.notifData.actions || []

                                            delegate: NotificationActionButton {
                                                action: modelData
                                                onInvoked: hardClose()
                                            }

                                        }

                                    }

                                    // ── Mechanical Progress Bar ──
                                    Rectangle {
                                        id: progressBar

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 3
                                        color: toastCard.uColor
                                        visible: model.urgency !== 2 // Critical notifications don't timeout

                                        NumberAnimation {
                                            target: progressBar
                                            property: "width"
                                            to: 0
                                            duration: model.expireTimeout > 0 ? Math.min(model.expireTimeout, 8000) : 6000
                                            running: model.urgency !== 2 && !toastDelegate.hovered // Halts mechanically on hover
                                        }

                                    }

                                }

                                // Background click router
                                MouseArea {
                                    anchors.fill: parent
                                    z: -1 // Push behind close buttons and actions
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton && !closing)
                                            invokeDefault();
                                        else if (mouse.button === Qt.RightButton)
                                            close();
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
