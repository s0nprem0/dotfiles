import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: playerSectionRoot

    required property var mediaRoot

    opacity: mediaRoot.mediaFade
    visible: mediaRoot.hasPlayer
    width: parent.width
    implicitHeight: mediaColumn.implicitHeight

    Column {
        id: mediaColumn

        width: parent.width
        spacing: 6

        // ── Section 2: Album Art + Track Info ──
        Row {
            visible: mediaRoot.hasPlayer
            width: parent.width
            spacing: 8

            Rectangle {
                id: artFrame

                width: 48
                height: 48
                color: Theme.surface
                border.width: 1
                border.color: Theme.primary
                clip: true
                radius: 0

                Image {
                    id: artImage

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: mediaRoot.artUrl || ""
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    visible: !mediaRoot.artUrl || artImage.status === Image.Error
                    renderType: Text.NativeRendering
                }

            }

            Column {
                width: parent.width - 56
                anchors.verticalCenter: artFrame.verticalCenter
                spacing: 1

                Row {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width - sourceIndicatorRow.implicitWidth - 6
                        text: mediaRoot.title || "No Track"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Row {
                        id: sourceIndicatorRow

                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        visible: mediaRoot.availablePlayers.length > 1
                        height: 8

                        Repeater {
                            model: mediaRoot.availablePlayers

                            delegate: Rectangle {
                                width: 5
                                height: 5
                                radius: 0
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData === mediaRoot.playerName ? Theme.primary : Theme.surface
                                border.width: 1
                                border.color: Theme.primary
                                opacity: modelData === mediaRoot.playerName ? 1 : 0.55
                            }

                        }

                    }

                }

                Text {
                    text: mediaRoot.artist ? mediaRoot.artist + (mediaRoot.album ? " • " + mediaRoot.album : "") : (mediaRoot.playerName || "")
                    width: parent.width
                    color: Theme.primary
                    opacity: 0.6
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Row {
                    spacing: 4
                    visible: mediaRoot.playerStatus

                    Rectangle {
                        height: 4
                        width: 4
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: mediaRoot.playerStatus === "Playing" ? Theme.green : mediaRoot.playerStatus === "Paused" ? Theme.warning : Theme.muted
                    }

                    Text {
                        text: mediaRoot.playerStatus || ""
                        color: mediaRoot.playerStatus === "Playing" ? Theme.green : mediaRoot.playerStatus === "Paused" ? Theme.warning : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                        renderType: Text.NativeRendering
                    }

                }

            }

        }

        // ── Section 3: Controls ──
        Row {
            visible: mediaRoot.hasPlayer
            width: parent.width
            spacing: 12

            Text {
                id: shuffleLabel

                text: "󰒝"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.5
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.opacity = 1
                    onExited: parent.opacity = 0.5
                    onClicked: mediaRoot.playerCtl(["shuffle", "toggle"])
                }

            }

            Text {
                id: prevLabel

                text: "prev"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: mediaRoot.playerCtl(["previous"])
                }

            }

            Text {
                id: playLabel

                text: mediaRoot.playerStatus === "Playing" ? "pause" : "play"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: mediaRoot.playerCtl(["play-pause"])
                }

            }

            Text {
                id: nextLabel

                text: "next"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: mediaRoot.playerCtl(["next"])
                }

            }

            Text {
                id: stopLabel

                text: "stop"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.6
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: mediaRoot.playerCtl(["stop"])
                }

            }

            Text {
                id: repeatLabel

                text: "󰑘"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.5
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.opacity = 1
                    onExited: parent.opacity = 0.5
                    onClicked: mediaRoot.playerCtl(["repeat", "toggle"])
                }

            }

            Text {
                id: sourceSwitchLabel

                text: "󰑖"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                visible: mediaRoot.availablePlayers.length > 1
                opacity: 0.5
                renderType: Text.NativeRendering

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.opacity = 1
                    onExited: parent.opacity = 0.5
                    onClicked: {
                        mediaRoot.switchMediaSource();
                    }
                }

            }

        }

        // ── Section 4: Seek Bar ──
        Row {
            visible: mediaRoot.hasPlayer && mediaRoot.trackLength > 0
            width: parent.width
            spacing: 6
            height: 14

            Text {
                id: seekTimeStart

                text: mediaRoot.formatTime(mediaRoot.position)
                color: Theme.primary
                opacity: 0.5
                font.family: Theme.fontFamily
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }

            Item {
                width: parent.width - seekTimeStart.implicitWidth - seekTimeEnd.implicitWidth - parent.spacing * 2
                height: parent.height
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    color: Theme.surface

                    Rectangle {
                        width: parent.width * Math.min(1, mediaRoot.position / (mediaRoot.trackLength / 1e+06))
                        height: parent.height
                        color: Theme.primary
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var frac = Math.max(0, Math.min(1, mouse.x / width));
                        var secs = frac * (mediaRoot.trackLength / 1e+06);
                        mediaRoot.playerCtl(["position", secs.toFixed(1)]);
                    }
                }

            }

            Text {
                id: seekTimeEnd

                text: mediaRoot.formatTime(mediaRoot.trackLength / 1e+06)
                color: Theme.primary
                opacity: 0.5
                font.family: Theme.fontFamily
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }

        }

        // ── Section 5: Player Volume ──
        Column {
            visible: mediaRoot.hasPlayer
            width: parent.width
            spacing: 4

            Row {
                width: parent.width

                Text {
                    text: "󰕾 Volume: " + Math.round(mediaRoot.volume * 100) + "%"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }

                Item {
                    width: parent.width - childrenRect.width - mutePlayerText.width
                    height: 1
                }

                Text {
                    id: mutePlayerText

                    text: mediaRoot.volume === 0 ? "Unmute" : "Mute"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: mediaRoot.playerCtl(["volume", mediaRoot.volume === 0 ? "1.0" : "0.0"])
                    }

                }

            }

            Item {
                width: parent.width
                height: 8

                BlockSlider {
                    currentVal: Math.min(1, mediaRoot.volume)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    emptyColor: Theme.surface
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: mediaRoot.playerCtl(["volume", Math.max(0.01, Math.min(1, mouse.x / width)).toFixed(2)])
                    onPositionChanged: {
                        if (pressed) {
                            var v = Math.max(0.01, Math.min(1, mouse.x / width));
                            if (Math.abs(v - mediaRoot.volume) > 0.02)
                                mediaRoot.playerCtl(["volume", v.toFixed(2)]);

                        }
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: function(event) {
                        var delta = event.angleDelta.y / 120;
                        var newVol = Math.max(0, Math.min(1, mediaRoot.volume + delta * 0.05));
                        mediaRoot.playerCtl(["volume", newVol.toFixed(2)]);
                    }
                }

            }

        }

    }

    transform: Translate {
        y: mediaRoot.mediaSlide
    }

}
