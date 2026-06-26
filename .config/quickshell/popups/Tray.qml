import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

PopupPanel {
    id: root

    property var activeItem: null
    property bool showMenu: false
    property real menuX: 0
    property int menuSelectedIndex: -1
    property int trayIndex: -1
    property var activeSubmenu: null
    property bool showSubmenu: false
    property real submenuX: 0
    property real submenuY: 0
    property int submenuSelectedIndex: -1
    property real menuAnimOpacity: 0
    property real menuScale: 0.92

    function nextMenuIndex(current, dir) {
        var next = current + dir;
        var children = menuOpener.children.values;
        while (next >= 0 && next < children.length) {
            if (!children[next].isSeparator)
                return next;

            next += dir;
        }
        return current;
    }

    function nextSubmenuIndex(current, dir) {
        var next = current + dir;
        var children = submenuOpener.children.values;
        while (next >= 0 && next < children.length) {
            if (!children[next].isSeparator)
                return next;

            next += dir;
        }
        return current;
    }

    function openMenuItem(item, iconCenterX) {
        root.activeItem = item;
        root.menuX = iconCenterX;
        if (!root.showMenu) {
            root.menuAnimOpacity = 0;
            root.menuScale = 0.92;
            root.showMenu = true;
            root.menuSelectedIndex = root.nextMenuIndex(-1, 1);
            menuCloseAnim.stop();
            menuOpenAnim.start();
        }
    }

    function openSubmenu(entry, x, y) {
        if (root.showSubmenu)
            root.closeSubmenu();

        root.activeSubmenu = entry;
        root.submenuX = x;
        root.submenuY = y;
        root.showSubmenu = true;
        root.submenuSelectedIndex = root.nextSubmenuIndex(-1, 1);
    }

    function closeSubmenu() {
        root.showSubmenu = false;
        root.activeSubmenu = null;
        root.submenuSelectedIndex = -1;
    }

    function closeMenu() {
        if (!root.showMenu || menuCloseAnim.running)
            return ;

        menuOpenAnim.stop();
        menuCloseAnim.start();
    }

    anchorSide: "right"
    panelWidth: 280
    panelMinHeight: 300
    Component.onCompleted: {
        SystemTray.isService = false;
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.activeItem ? root.activeItem.menu : null
    }

    QsMenuOpener {
        id: submenuOpener

        menu: root.activeSubmenu
    }

    ParallelAnimation {
        id: menuOpenAnim

        NumberAnimation {
            target: root
            property: "menuAnimOpacity"
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "menuScale"
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

    ParallelAnimation {
        id: menuCloseAnim

        onStopped: {
            root.showMenu = false;
            root.activeItem = null;
            root.menuSelectedIndex = -1;
            root.closeSubmenu();
        }

        NumberAnimation {
            target: root
            property: "menuAnimOpacity"
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "menuScale"
            to: 0.92
            duration: 100
            easing.type: Easing.InCubic
        }

    }

    contentComponent: Component {
        FocusScope {
            anchors.fill: parent
            focus: true
            implicitWidth: root.panelWidth - root.contentMargin * 2
            implicitHeight: Math.max(contentLayout.implicitHeight, 300)

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                spacing: 0

                Keys.onPressed: (event) => {
                    if (root.showMenu) {
                        if (root.showSubmenu) {
                            switch (event.key) {
                            case Qt.Key_Up:
                                root.submenuSelectedIndex = root.nextSubmenuIndex(root.submenuSelectedIndex, -1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Down:
                                root.submenuSelectedIndex = root.nextSubmenuIndex(root.submenuSelectedIndex, 1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Space:
                                {
                                    var subChildren = submenuOpener.children.values;
                                    if (root.submenuSelectedIndex >= 0 && root.submenuSelectedIndex < subChildren.length) {
                                        var subEntry = subChildren[root.submenuSelectedIndex];
                                        if (subEntry.enabled && !subEntry.isSeparator) {
                                            subEntry.triggered();
                                            root.closePopup();
                                        }
                                    }
                                    event.accepted = true;
                                    break;
                                }
                            case Qt.Key_Escape:
                            case Qt.Key_Left:
                                root.closeSubmenu();
                                event.accepted = true;
                                break;
                            }
                        } else {
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
                            case Qt.Key_Space:
                                {
                                    var children = menuOpener.children.values;
                                    if (root.menuSelectedIndex >= 0 && root.menuSelectedIndex < children.length) {
                                    var entry = children[root.menuSelectedIndex];
                                    if (entry.enabled && !entry.isSeparator) {
                                        if (entry.hasChildren) {
                                            var subX = menuContent.x + menuContent.width;
                                            var subY = menuContent.y + 4 + root.menuSelectedIndex * 23 - menuFlick.contentY;
                                            root.openSubmenu(entry, subX, subY);
                                        } else {
                                            entry.triggered();
                                            root.closePopup();
                                        }
                                    }
                                }
                                event.accepted = true;
                                break;
                            };
                        case Qt.Key_Escape:
                            root.closeMenu();
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                            root.closeMenu();
                            root.trayIndex = Math.max(0, root.trayIndex - 1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Right:
                            {
                                var children = menuOpener.children.values;
                                if (root.menuSelectedIndex >= 0 && root.menuSelectedIndex < children.length) {
                                    var entry = children[root.menuSelectedIndex];
                                    if (entry.hasChildren) {
                                        var subX = menuContent.x + menuContent.width;
                                        var subY = menuContent.y + 4 + root.menuSelectedIndex * 23 - menuFlick.contentY;
                                        root.openSubmenu(entry, subX, subY);
                                    } else {
                                        root.closeMenu();
                                        root.trayIndex = Math.min(SystemTray.items.length - 1, root.trayIndex + 1);
                                    }
                                } else {
                                    root.closeMenu();
                                    root.trayIndex = Math.min(SystemTray.items.length - 1, root.trayIndex + 1);
                                }
                                event.accepted = true;
                                break;
                            };
                        }
                    }
                } else {
                    switch (event.key) {
                    case Qt.Key_Left:
                        root.trayIndex = Math.max(0, root.trayIndex - 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        root.trayIndex = Math.min(SystemTray.items.length - 1, root.trayIndex + 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Space:
                        {
                            var item = SystemTray.items.values[root.trayIndex];
                            if (item) {
                                if (item.hasMenu) {
                                    root.openMenuItem(item, trayBar.width / 2);
                                } else {
                                    item.activate();
                                    root.closePopup();
                                }
                            }
                            event.accepted = true;
                            break;
                        };
                    }
                }
            }

            Connections {
                function onBeforeOpen() {
                    root.trayIndex = SystemTray.items.length > 0 ? 0 : -1;
                }

                function onMenuSelectedIndexChanged() {
                    if (!root.showMenu || root.menuSelectedIndex < 0 || !menuFlick)
                        return ;

                    var itemH = 23;
                    var itemY = root.menuSelectedIndex * itemH;
                    if (itemY < menuFlick.contentY)
                        menuFlick.contentY = itemY;
                    else if (itemY + 22 > menuFlick.contentY + menuFlick.height)
                        menuFlick.contentY = itemY + 22 - menuFlick.height;
                }

                function onSubmenuSelectedIndexChanged() {
                    if (!root.showSubmenu || root.submenuSelectedIndex < 0 || !submenuFlick)
                        return ;

                    var itemH = 23;
                    var itemY = root.submenuSelectedIndex * itemH;
                    if (itemY < submenuFlick.contentY)
                        submenuFlick.contentY = itemY;
                    else if (itemY + 22 > submenuFlick.contentY + submenuFlick.height)
                        submenuFlick.contentY = itemY + 22 - submenuFlick.height;
                }

                target: root
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Rectangle {
                    id: trayBar

                    Layout.fillWidth: true
                    height: 34
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.primary
                    radius: 4

                    Row {
                        id: iconRow

                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: SystemTray.items

                            delegate: Rectangle {
                                id: trayIconItem

                                required property var modelData
                                required property int index

                                width: 18
                                height: 18
                                color: trayIconMouse.containsMouse || index === root.trayIndex ? Theme.primaryAlpha015 : "transparent"
                                radius: 2

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    visible: status !== Image.Error
                                }

                                MouseArea {
                                    id: trayIconMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        root.trayIndex = index;
                                        if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu) {
                                                var center = trayIconItem.mapToItem(menuContent.parent, trayIconItem.width / 2, 0);
                                                root.openMenuItem(modelData, center.x);
                                            }
                                        } else {
                                            if (modelData.hasMenu && modelData.onlyMenu) {
                                                var center = trayIconItem.mapToItem(menuContent.parent, trayIconItem.width / 2, 0);
                                                root.openMenuItem(modelData, center.x);
                                            } else {
                                                modelData.activate();
                                                root.closePopup();
                                            }
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
                opacity: root.menuAnimOpacity
                scale: root.menuScale
                transformOrigin: Item.Bottom
                anchors.bottom: trayBar.top
                anchors.bottomMargin: 4
                x: Math.max(8, Math.min(parent.width - width - 8, root.menuX - width / 2))

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
                                        return Theme.primaryAlpha015;

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

                                            if (modelData.icon)
                                                return "";

                                            return "";
                                        }
                                        color: Theme.fg
                                        font.pixelSize: Theme.fontSizeSm
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Image {
                                        width: 12
                                        height: 12
                                        source: modelData.icon
                                        visible: modelData.icon !== "" && status !== Image.Error
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: 12
                                        sourceSize.height: 12
                                    }

                                    Text {
                                        text: modelData.text.replace(/&/g, "")
                                        color: modelData.enabled ? Theme.fg : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMd
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "▸"
                                        visible: modelData.hasChildren
                                        color: modelData.enabled ? Theme.fg : Theme.muted
                                        font.pixelSize: Theme.fontSizeSm
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                }

                                MouseArea {
                                    id: menuMouse

                                    anchors.fill: parent
                                    hoverEnabled: modelData.enabled && !modelData.isSeparator
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (modelData.enabled && !modelData.isSeparator) {
                                            if (modelData.hasChildren) {
                                                var subX = menuContent.x + menuContent.width;
                                                var subY = menuContent.y + 4 + index * 23 - menuFlick.contentY;
                                                root.openSubmenu(modelData, subX, subY);
                                            } else {
                                                modelData.triggered();
                                                root.showMenu = false;
                                                root.showSubmenu = false;
                                                root.closePopup();
                                            }
                                        }
                                    }
                                }

                            }

                        }

                    }

                }

            }

            Rectangle {
                id: submenuContent

                visible: root.showSubmenu
                width: 180
                height: Math.min(submenuFlick.contentHeight + 8, Math.round(parent.height * 0.55))
                color: Theme.surface
                border.width: 1
                border.color: Theme.primary
                radius: 4
                clip: true
                z: 11
                opacity: root.menuAnimOpacity
                scale: root.menuScale
                transformOrigin: Item.Bottom
                x: Math.min(root.submenuX, parent.width - width - 4)
                y: Math.max(0, Math.min(root.submenuY, parent.height - height - 4))

                Flickable {
                    id: submenuFlick

                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: submenuColumn.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: submenuColumn

                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: submenuOpener.children

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: modelData.isSeparator ? 6 : 22
                                color: {
                                    if (modelData.isSeparator)
                                        return "transparent";

                                    if (submenuMouse.containsMouse || index === root.submenuSelectedIndex)
                                        return Theme.primaryAlpha015;

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

                                            if (modelData.icon)
                                                return "";

                                            return "";
                                        }
                                        color: Theme.fg
                                        font.pixelSize: Theme.fontSizeSm
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Image {
                                        width: 12
                                        height: 12
                                        source: modelData.icon
                                        visible: modelData.icon !== "" && status !== Image.Error
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: 12
                                        sourceSize.height: 12
                                    }

                                    Text {
                                        text: modelData.text.replace(/&/g, "")
                                        color: modelData.enabled ? Theme.fg : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMd
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "▸"
                                        visible: modelData.hasChildren
                                        color: modelData.enabled ? Theme.fg : Theme.muted
                                        font.pixelSize: Theme.fontSizeSm
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                }

                                MouseArea {
                                    id: submenuMouse

                                    anchors.fill: parent
                                    hoverEnabled: modelData.enabled && !modelData.isSeparator
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (modelData.enabled && !modelData.isSeparator) {
                                            if (modelData.hasChildren) {
                                                var subX = submenuContent.x + submenuContent.width;
                                                var subY = submenuContent.y + 4 + index * 23 - submenuFlick.contentY;
                                                root.openSubmenu(modelData, subX, subY);
                                            } else {
                                                modelData.triggered();
                                                root.showMenu = false;
                                                root.showSubmenu = false;
                                                root.closePopup();
                                            }
                                        }
                                    }
                                }

                            }

                        }

                    }

                }

            }

            MouseArea {
                anchors.top: parent.top
                anchors.bottom: trayBar.top
                anchors.left: parent.left
                anchors.right: parent.right
                visible: root.showMenu
                z: 9
                onClicked: root.closeMenu()
            }

        }

    }

}

}
