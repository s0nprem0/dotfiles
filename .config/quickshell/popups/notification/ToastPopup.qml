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
                // Low

                id: toastPopup

                required property var modelData

                function urgencyColor(urgency) {
                    if (urgency === 2)
                        return Theme.error;

                    // Critical
                    if (urgency === 1)
                        return Theme.primary;

                    // Normal
                    return Theme.muted;
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
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 2

                    Repeater {
                        id: toastRepeater

                        model: NotificationState.toastModel

                        delegate: Item {
                            id: toastDelegate

                            property real opacityValue: 0
                            property bool closing: false
                            property bool hovered: false
                            property var liveData: model.notifData || model

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

                            width: parent.width
                            height: toastCard.height
                            Component.onCompleted: {
                                opacityValue = 1;
                            }

                            Timer {
                                id: closeTimer

                                interval: 50
                                onTriggered: {
                                    if (NotificationState.service && model && model.notifId !== undefined)
                                        NotificationState.service.dismissToastById(model.notifId);

                                }
                            }

                            Timer {
                                id: softCloseTimer

                                interval: 50
                                onTriggered: {
                                    if (NotificationState.service && model && model.notifId !== undefined)
                                        NotificationState.service.softDismissToastById(model.notifId);

                                }
                            }

                            Timer {
                                id: dismissTimer

                                interval: liveData.expireTimeout > 0 ? Math.min(liveData.expireTimeout, 8000) : (liveData.urgency === 2 ? 8000 : 6000)
                                running: !toastDelegate.hovered && liveData.expireTimeout !== 0
                                onTriggered: {
                                    if (model && model.notifId !== undefined)
                                        autoClose();

                                }
                            }

                            // ── Brutalist Notification Card ──
                            Rectangle {
                                id: toastCard

                                readonly property int urg: liveData.urgency
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
                                                text: liveData.urgency === 2 ? "󰀦" : (!liveData.appIcon || liveData.appIcon.length === 0 ? IconResolver.nerdFontGlyph(liveData.appName) : "󰂚")
                                                color: toastCard.uColor
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                            }

                                            Text {
                                                text: (liveData.appName || "SYSTEM").toUpperCase()
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: "󰃁"
                                                color: toastCard.uColor
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                visible: liveData.expireTimeout === 0
                                                anchors.verticalCenter: parent.verticalCenter
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
                                                text: (liveData.summary || "").toUpperCase()
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
                                                text: liveData.body || ""
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

                                    // ── Row 2.5: Hint Progress Bar ──
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        Layout.rightMargin: 12
                                        height: 4
                                        color: Qt.alpha(Theme.primary, 0.1)
                                        visible: liveData.hints && liveData.hints.value !== undefined

                                        Rectangle {
                                            width: parent.width * Math.min(1, Math.max(0, (liveData.hints.value / (liveData.hints.maximum || 100))))
                                            height: parent.height
                                            color: Theme.primary
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
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 3
                                        clip: true
                                        color: "transparent"
                                        visible: liveData.urgency !== 2

                                        Rectangle {
                                            id: progressBarFill

                                            width: 0
                                            height: parent.height
                                            color: toastCard.uColor

                                            NumberAnimation on width {
                                                from: progressBarFill.parent.width
                                                to: 0
                                                duration: liveData.expireTimeout > 0 ? Math.min(liveData.expireTimeout, 8000) : 6000
                                                running: liveData.urgency !== 2 && !toastDelegate.hovered
                                            }

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

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
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
