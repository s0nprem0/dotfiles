import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string fileQuery: ""
    property bool isSearching: false

    signal fileSelected(string path)
    signal indexRequested()

    function rebuildDisplay() {
        var items = [];
        items.push({ typeLabel: "HEADER", name: fileQuery ? "SEARCHING: " + fileQuery.toUpperCase() : "FILE SEARCH" });

        if (root.isSearching) {
            items.push({
                typeLabel: "SEARCH",
                name: "SEARCHING...",
                icon: "󰉋",
                comment: "@" + root.fileQuery
            });
        } else {
            items.push({
                typeLabel: "INDEX",
                name: "INDEX FILES NOW",
                icon: "󰇚",
                comment: "scan home directory with fd (excludes .git, node_modules, .cache, target)",
                isIndexAction: true
            });
        }

        root.displayData = items;
    }

    property var displayData: []
    property int selectedIndex: 0

    onFileQueryChanged: rebuildDisplay()
    onIsSearchingChanged: rebuildDisplay()

    Component.onCompleted: rebuildDisplay()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            id: listView

            model: root.displayData
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

                width: ListView.view.width
                height: modelData.typeLabel === "HEADER" ? 28 : 40

                Rectangle {
                    anchors.fill: parent
                    color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : (ma.containsMouse ? Theme.surfaceLighter : "transparent"))
                    border.width: modelData.typeLabel === "HEADER" ? 0 : 1
                    border.color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : Qt.alpha(Theme.primary, 0.1))

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.typeLabel === "HEADER" ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (modelData.typeLabel !== "HEADER")
                                root.selectedIndex = index;
                        }
                        onClicked: root.fileSelected(modelData.path || "")
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: modelData.typeLabel === "HEADER" ? 12 : 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.name || ""
                        color: modelData.typeLabel === "HEADER" ? Theme.muted : (root.selectedIndex === index ? Theme.bg : Theme.fg)
                        font.family: Theme.fontFamily
                        font.pixelSize: modelData.typeLabel === "HEADER" ? 8 : 10
                        font.bold: modelData.typeLabel === "HEADER" ? true : false
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}