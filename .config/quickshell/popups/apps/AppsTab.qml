import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property alias searchText: searchField.text
    property alias selectedIndex: listView.currentIndex
    property alias displayData: listView.model

    signal itemSelected(var item)

    function moveUp() {
        if (root.selectedIndex > 0)
            root.selectedIndex--;
    }

    function moveDown() {
        if (root.selectedIndex < root.displayData.length - 1)
            root.selectedIndex++;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        TextInput {
            id: searchField

            Layout.fillWidth: true
            implicitHeight: 28
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXl
            font.bold: true
            selectByMouse: true
            clip: true
            onTextChanged: root.selectedIndex = 0

            Keys.onPressed: {
                if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                    root.moveUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                    root.moveDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.itemSelected(root.displayData[root.selectedIndex]);
                    event.accepted = true;
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            id: listView

            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ListView.contentHeight > ListView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                contentItem: Rectangle {
                    implicitWidth: 4
                    color: Theme.primary
                    radius: 0
                }
            }

            delegate: Item {
                required property var modelData
                required property int index

                width: ListView.view.width - (listView.ScrollBar.vertical.visible ? 8 : 0)
                height: modelData.typeLabel === "HEADER" ? 24 : 40

                Rectangle {
                    anchors.fill: parent
                    color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : (ma.containsMouse ? Theme.surfaceLighter : "transparent"))
                    border.width: modelData.typeLabel === "HEADER" ? 0 : 1
                    border.color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : "transparent")

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.typeLabel === "HEADER" ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (modelData.typeLabel !== "HEADER")
                                root.selectedIndex = index;
                        }
                        onClicked: root.itemSelected(modelData)
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: modelData.typeLabel === "HEADER" ? 0 : 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.name || ""
                        color: modelData.typeLabel === "HEADER" ? Theme.muted : (root.selectedIndex === index ? Theme.bg : Theme.fg)
                        font.family: Theme.fontFamily
                        font.pixelSize: modelData.typeLabel === "HEADER" ? 8 : 10
                        font.bold: modelData.typeLabel === "HEADER" ? true : false
                        visible: modelData.typeLabel === "HEADER"
                    }

                    Item {
                        anchors.fill: parent
                        visible: modelData.typeLabel !== "HEADER"

                        Item {
                            id: itemIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon || "󰣇"
                                color: root.selectedIndex === index ? Theme.bg : Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize3xl
                                visible: imgIcon.status === Image.Error || modelData.typeLabel !== "APP"
                            }

                            Image {
                                id: imgIcon
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: modelData.typeLabel === "APP" && modelData.icon ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon) : ""
                                visible: modelData.typeLabel === "APP" && status !== Image.Error
                                sourceSize.width: 16
                                sourceSize.height: 16
                            }
                        }

                        Text {
                            id: enterIndicator
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↵"
                            visible: root.selectedIndex === index
                            color: Theme.bg
                            font.pixelSize: Theme.fontSize3xl
                            font.bold: true
                            width: visible ? 16 : 0
                        }

                        Item {
                            anchors.left: itemIcon.right
                            anchors.leftMargin: 12
                            anchors.right: enterIndicator.visible ? enterIndicator.left : parent.right
                            anchors.rightMargin: enterIndicator.visible ? 8 : 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: modelData.comment !== "" ? 20 : 12

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: (modelData.name || "").toUpperCase()
                                color: root.selectedIndex === index ? Theme.bg : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: (modelData.comment || "")
                                color: root.selectedIndex === index ? Qt.alpha(Theme.bg, 0.7) : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                elide: Text.ElideRight
                                visible: modelData.comment !== ""
                            }
                        }
                    }
                }
            }
        }
    }
}