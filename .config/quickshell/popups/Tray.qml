import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

PopupPanel {
    id: root

    anchorSide: "right"
    panelWidth: 280
    panelMinHeight: 300

    property var activeItem: null
    property bool showMenu: false
    property real menuX: 0
    property real menuY: 0
    property int menuSelectedIndex: -1

    function nextMenuIndex(current, dir) {
        var next = current + dir;
        var children = menuOpener.children.values;
        while (next >= 0 && next < children.length) {
            if (!children[next].isSeparator) return next;
            next += dir;
        }
        return current;
    }

    Component.onCompleted: {
        SystemTray.isService = false;
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.activeItem ? root.activeItem.menu : null
    }

    function openMenuItem(item, x, y) {
        root.activeItem = item;
        root.menuX = x;
        root.menuY = y;
        root.showMenu = true;
        root.menuSelectedIndex = root.nextMenuIndex(-1, 1);
    }

    function closeMenu() {
        root.showMenu = false;
        root.activeItem = null;
        root.menuSelectedIndex = -1;
    }

    contentComponent: Component {
        FocusScope {
            anchors.fill: parent
            focus: true
            implicitWidth: root.panelWidth - root.contentMargin * 2
            implicitHeight: Math.max(contentLayout.implicitHeight, 300)

            Keys.onPressed: (event) => {
                if (root.showMenu) {
                    switch (event.key) {
                        case Qt.Key_Up:
                            root.menuSelectedIndex = root.nextMenuIndex(root.menuSelectedIndex, -1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Down:
                            root.menuSelectedIndex = root.nextMenuIndex(root.menuSelectedIndex, 1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Space: {
                            var children = menuOpener.children.values;
                            if (root.menuSelectedIndex >= 0 && root.menuSelectedIndex < children.length) {
                                var entry = children[root.menuSelectedIndex];
                                if (entry.enabled && !entry.isSeparator) {
                                    entry.triggered();
                                    root.closePopup();
                                }
                            }
                            event.accepted = true;
                            break;
                        }
                        case Qt.Key_Escape:
                            root.closeMenu();
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                        case Qt.Key_Right: {
                            root.closeMenu();
                            if (event.key === Qt.Key_Left)
                                trayList.currentIndex = Math.max(0, trayList.currentIndex - 1);
                            else
                                trayList.currentIndex = Math.min(SystemTray.items.length - 1, trayList.currentIndex + 1);
                            event.accepted = true;
                            break;
                        }
                    }
                } else {
                    switch (event.key) {
                        case Qt.Key_Down:
                            trayList.currentIndex = Math.min(trayList.currentIndex + 1, SystemTray.items.length - 1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Up:
                            trayList.currentIndex = Math.max(trayList.currentIndex - 1, 0);
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                            trayList.currentIndex = Math.max(0, trayList.currentIndex - 1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Right:
                            trayList.currentIndex = Math.min(SystemTray.items.length - 1, trayList.currentIndex + 1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Space: {
                            var item = SystemTray.items.values[trayList.currentIndex];
                            if (item) {
                                if (item.hasMenu && item.onlyMenu)
                                    root.openMenuItem(item, trayList.width - 186, trayList.currentIndex * 30);
                                else {
                                    item.activate();
                                    root.closePopup();
                                }
                            }
                            event.accepted = true;
                            break;
                        }
                    }
                }
            }

            Connections {
                target: root
                function onBeforeOpen() {
                    trayList.currentIndex = SystemTray.items.length > 0 ? 0 : -1;
                }
                function onMenuSelectedIndexChanged() {
                    if (!root.showMenu || root.menuSelectedIndex < 0 || !menuFlick)
                        return;
                    var itemH = 23;
                    var itemY = root.menuSelectedIndex * itemH;
                    if (itemY < menuFlick.contentY)
                        menuFlick.contentY = itemY;
                    else if (itemY + 22 > menuFlick.contentY + menuFlick.height)
                        menuFlick.contentY = itemY + 22 - menuFlick.height;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: "󰟸  System Tray"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    Layout.bottomMargin: 4
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ListView {
                        id: trayList
                        anchors.fill: parent
                        clip: true
                        model: SystemTray.items
                        spacing: 2
                        currentIndex: -1

                        Text {
                            anchors.centerIn: parent
                            text: "No tray items"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            visible: SystemTray.items.length === 0
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: trayList.width
                            height: 28
                            color: itemMouse.containsMouse || index === trayList.currentIndex
                                ? Qt.alpha(Theme.primary, 0.12) : "transparent"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    id: trayIcon
                                    width: 16; height: 16
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 16; sourceSize.height: 16
                                    visible: status !== Image.Error
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.title || modelData.id || "Unknown"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    trayList.currentIndex = index;
                                    if (mouse.button === Qt.LeftButton) {
                                        if (modelData.hasMenu && modelData.onlyMenu) {
                                            var pos = mapToItem(trayList, width, 0);
                                            root.openMenuItem(modelData, pos.x, pos.y);
                                        } else {
                                            modelData.activate();
                                            root.closePopup();
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            var pos2 = mapToItem(trayList, width, 0);
                                            root.openMenuItem(modelData, pos2.x, pos2.y);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: menuContent
                visible: root.showMenu
                width: 180
                height: Math.min(menuFlick.contentHeight + 8, Math.round(parent.height * 0.55))
                color: Theme.surface
                border.width: 1
                border.color: Theme.primary
                radius: 4
                clip: true
                z: 10
                x: Math.min(root.menuX, trayList.width - width - 4)
                y: Math.max(0, Math.min(root.menuY, parent.height - height - 4))

                Flickable {
                    id: menuFlick
                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: menuColumn.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: menuColumn
                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: menuOpener.children

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: modelData.isSeparator ? 6 : 22
                                color: {
                                    if (modelData.isSeparator)
                                        return "transparent";
                                    if (menuMouse.containsMouse || index === root.menuSelectedIndex)
                                        return Qt.alpha(Theme.primary, 0.15);
                                    return "transparent";
                                }

                                Rectangle {
                                    visible: modelData.isSeparator
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 1
                                    color: Theme.muted
                                }

                                RowLayout {
                                    visible: !modelData.isSeparator
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Text {
                                        width: 12
                                        text: {
                                            if (modelData.buttonType === 1 || modelData.buttonType === 2)
                                                return modelData.checkState === Qt.Checked ? "✓" : "";
                                            if (modelData.icon) return "";
                                            return "";
                                        }
                                        color: Theme.fg
                                        font.pixelSize: 9
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Image {
                                        width: 12; height: 12
                                        source: modelData.icon
                                        visible: modelData.icon !== "" && status !== Image.Error
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: 12; sourceSize.height: 12
                                    }

                                    Text {
                                        text: modelData.text.replace(/&/g, "")
                                        color: modelData.enabled ? Theme.fg : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: menuMouse
                                    anchors.fill: parent
                                    hoverEnabled: modelData.enabled && !modelData.isSeparator
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (modelData.enabled && !modelData.isSeparator) {
                                            modelData.triggered();
                                            root.closePopup();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: root.showMenu
                z: 9
                onClicked: root.closeMenu()
            }
        }
    }
}
