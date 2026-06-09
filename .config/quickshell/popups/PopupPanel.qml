import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../service"

Item {
    id: root

    // ── Configuration ──
    property string anchorSide: "left"
    property int panelWidth: 340
    property int panelMinHeight: 0
    property int panelMaxHeight: 0
    property int initialOffset: -360
    property int finalInset: 12
    property int introDuration: 120
    property int exitDuration: 100
    property int contentMargin: 10

    // ── State ──
    property bool showPopup: false
    property bool isClosing: false
    property real animOffset: root.initialOffset
    property real animOpacity: 0

    // ── Content (set by popup file) ──
    property Component contentComponent

    // ── Signals ──
    signal beforeOpen()
    signal afterOpen()
    signal beforeClose()

    // ── Show / Hide ──
    onShowPopupChanged: {
        if (root.showPopup) {
            exitAnim.stop()
            isClosing = false
            animOffset = root.initialOffset
            animOpacity = 0
            doShow()
            root.beforeOpen()
        } else if (!isClosing) {
            introAnim.stop()
            closePopup()
        }
    }

    function doShow() {
        for (var key in screenWins) {
            var w = screenWins[key]
            if (w) w.visible = true
        }
        introAnim.start()
    }

    function closePopup() {
        if (isClosing) return
        isClosing = true
        root.beforeClose()
        exitAnim.start()
    }

    // ── Per-screen Windows ──
    property var screenWins: ({})

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData

                screen: modelData
                visible: false
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true

                implicitWidth: root.panelWidth
                implicitHeight: {
                    var h = contentLoader.implicitHeight + root.contentMargin * 2
                    if (root.panelMinHeight > 0) h = Math.max(h, root.panelMinHeight)
                    if (root.panelMaxHeight > 0) h = Math.min(h, root.panelMaxHeight)
                    return h
                }

                anchors {
                    top: root.anchorSide !== "none" ? true : false
                    left: root.anchorSide === "left" ? true : false
                    right: root.anchorSide === "right" ? true : false
                }

                margins {
                    top: root.anchorSide !== "none" ? 40 : 0
                    left: root.anchorSide === "left" ? root.animOffset : 0
                    right: root.anchorSide === "right" ? root.animOffset : 0
                }

                Rectangle {
                    id: contentRect
                    anchors.fill: parent
                    opacity: root.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: root.anchorSide === "none" ? 8 : 0
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.closePopup()
                            event.accepted = true
                        }
                    }

                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        anchors.margins: root.contentMargin
                        sourceComponent: root.contentComponent
                        onItemChanged: {
                            if (item) item.forceActiveFocus()
                        }
                    }
                }

                Component.onCompleted: {
                    root.screenWins[modelData] = win
                }
            }
        }
    }

    // ── Animations ──
    ParallelAnimation {
        id: introAnim

        onStopped: {
            if (!root.isClosing) root.afterOpen()
        }

        NumberAnimation {
            target: root
            property: "animOffset"
            from: root.initialOffset
            to: root.finalInset
            duration: root.introDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "animOpacity"
            from: 0
            to: 1
            duration: root.introDuration
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: root
            property: "animOffset"
            from: root.finalInset
            to: root.initialOffset
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "animOpacity"
            from: 1
            to: 0
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        onStopped: {
            for (var key in root.screenWins) {
                var w = root.screenWins[key]
                if (w) w.visible = false
            }
            root.showPopup = false
        }
    }
}
