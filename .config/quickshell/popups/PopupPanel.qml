import "../components"
import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    property string popupName: "default"
    property string anchorSide: "left"
    property int panelWidth: 340
    property int panelMinHeight: 0
    property int panelMaxHeight: 0
    property int initialOffset: -360
    property int finalInset: 12
    property int introDuration: 120
    property int exitDuration: 100
    property int contentMargin: 10
    property bool showPopup: false
    property Component contentComponent
    property var screenWins: new Map()

    signal beforeOpen()
    signal afterOpen()
    signal beforeClose()

    property int savedSection: 0
    property int savedSubIndex: 0
    property int progressHeight: 0
    property int progressWidth: 0

    function closePopup() {
        root.showPopup = false;
    }

    function saveFocusState(sec, sub) {
        root.savedSection = sec;
        root.savedSubIndex = sub;
        if (FocusState) {
            FocusState.saveState(root.popupName, sec, sub);
        }
    }

    onShowPopupChanged: {
        if (root.showPopup) {
            for (var w of screenWins.values()) {
                if (w)
                    w.visible = true;

            }
            root.beforeOpen();
            slide.show = true;
        } else if (!slide.closing) {
            root.beforeClose();
            slide.closeAnim();
        }
    }

    // ── Anchor-side popups (per-screen PanelWindow) ──
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
                WlrLayershell.namespace: "quickshell-popup"
                implicitWidth: root.panelWidth
                implicitHeight: {
                    var h = contentLoader.implicitHeight + root.contentMargin * 2;
                    if (root.panelMinHeight > 0)
                        h = Math.max(h, root.panelMinHeight);

                    if (root.panelMaxHeight > 0)
                        h = Math.min(h, root.panelMaxHeight);

                    return h;
                }
                Component.onCompleted: {
                    root.screenWins.set(modelData, win);
                }
                Component.onDestruction: {
                    root.screenWins.delete(modelData);
                }

                anchors {
                    top: true
                    left: root.anchorSide === "left" || root.anchorSide === "none" ? true : false
                    right: root.anchorSide === "right" ? true : false
                    bottom: false
                }

                margins {
                    top: 40
                    left: root.anchorSide === "left" ? slide.animSlide : root.anchorSide === "none" ? slide.animSlide : 0
                    right: root.anchorSide === "right" ? slide.animSlide : 0
                }

                Rectangle {
                    id: contentRect

                    anchors.fill: parent
                    opacity: slide.animOpacity
                    color: Theme.bg
                    border.width: 2
                    border.color: Theme.primary
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.closePopup();
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: root.progressHeight
                        color: Theme.primary
                        opacity: root.progressWidth > 0 ? 0.8 : 0
                        width: {
                            var contentWidth = contentLoader.implicitWidth || parent.width;
                            var maxWidth = parent.width - root.contentMargin * 2;
                            return (root.progressWidth / contentWidth) * maxWidth;
                        }
                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }

                    Loader {
                        id: contentLoader

                        anchors.fill: parent
                        anchors.margins: root.contentMargin
                        sourceComponent: root.contentComponent
                        onItemChanged: {
                            if (item)
                                item.forceActiveFocus();

                        }
                    }

                }

                HyprlandFocusGrab {
                    active: root.showPopup && !slide.closing
                    windows: [win]
                    onCleared: root.closePopup()
                }

            }

        }

    }

    SlideAnimator {
        id: slide

        slideFrom: root.initialOffset
        slideTo: root.finalInset
        introDuration: root.introDuration
        exitDuration: root.exitDuration
        onIntroCompleted: root.afterOpen()
        onExitCompleted: {
            for (var w of root.screenWins.values()) {
                if (w)
                    w.visible = false;

            }
        }
    }

}
