import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string searchText: ""
    property alias webHistory: webHistoryModel

    signal webActionRequested(string query, string url)
    signal searchExecuted(string query)

    ListModel {
        id: webHistoryModel
    }

    function rebuildDisplay() {
        var filtered = [];
        var term = root.searchText.trim();

        if (term.startsWith("!")) {
            var searchQuery = term.substring(1).trim();
            if (webHistoryModel.count > 0 && searchQuery.length > 0) {
                for (var i = 0; i < webHistoryModel.count; i++) {
                    var item = webHistoryModel.get(i);
                    if (item.query && item.query.toLowerCase().includes(searchQuery.toLowerCase())) {
                        filtered.push({
                            typeLabel: "WEB",
                            name: item.query,
                            icon: "󰖟",
                            comment: "via " + item.engine,
                            url: item.url
                        });
                    }
                }
            }
            filtered.push({
                typeLabel: "SEARCH",
                name: searchQuery ? "SEARCH \"" + searchQuery.toUpperCase() + "\"" : "EXECUTE WEB QUERY",
                icon: "󰖟",
                comment: term,
                query: term,
                isWebAction: true
            });
        }

        root.displayData = filtered;
    }

    property var displayData: []
    property int selectedIndex: 0

    signal displayDataChanged()

    onSearchTextChanged: {
        rebuildDisplay();
        selectedIndex = 0;
    }

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
                height: 40

                Rectangle {
                    anchors.fill: parent
                    color: root.selectedIndex === index ? Theme.primary : (ma.containsMouse ? Theme.surfaceLighter : "transparent")
                    border.width: 1
                    border.color: root.selectedIndex === index ? Theme.primary : Qt.alpha(Theme.primary, 0.1)

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: {
                            var item = root.displayData[root.selectedIndex];
                            if (item.isWebAction)
                                root.webActionRequested(item.query, item.url);
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon || "󰣇"
                        color: root.selectedIndex === index ? Theme.bg : Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize3xl
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || ""
                        color: root.selectedIndex === index ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}