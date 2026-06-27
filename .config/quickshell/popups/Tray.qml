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
    property int menuSelectedIndex: 0
    property int trayIndex: -1
    property var activeSubmenu: null
    property bool showSubmenu: false
    property real submenuX: 0
    property real submenuY: 0
    property int submenuSelectedIndex: -1
    property int itemHeight: 23

    function iconCenterX(index) {
        var count = SystemTray.items.length;
        var rowWidth = count * 18 + Math.max(0, count - 1) * 8;
        var rowLeft = (trayBar.width - rowWidth) / 2;
        return rowLeft + index * (18 + 8) + 9;
    }

    function nextMenuIndex(current, dir) {
        var next = current + dir;
        var children = menuOpener.children.values;
        var total = children.length;
        while (next >= 0 && next < total) {
            if (!children[next].isSeparator)
                return next;

            next += dir;
        }
        return current;
    }

    function nextSubmenuIndex(current, dir) {
        var next = current + dir;
        var children = submenuOpener.children.values;
        var total = children.length;
        while (next >= 0 && next < total) {
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
            root.showMenu = true;
            root.menuSelectedIndex = root.nextMenuIndex(-1, 1);
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
        if (!root.showMenu)
            return;
        root.showMenu = false;
        root.activeItem = null;
        root.menuSelectedIndex = -1;
        root.closeSubmenu();
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

    Timer {
        id: submenuHoverTimer

        interval: 200
        property int targetIndex: -1
        onTriggered: {
            if (!root.showMenu || targetIndex < 0)
                return;

            var children = menuOpener.children.values;
            var entry = children[targetIndex];
            if (entry && entry.hasChildren) {
                var subX = menuContent.x + menuContent.width;
                var subY = menuContent.y + 4 + targetIndex * root.itemHeight - menuFlick.contentY;
                root.openSubmenu(entry, subX, subY);
            }
        }
    }

    contentComponent: Component {
        FocusScope {
            anchors.fill: parent
            focus: true
            implicitWidth: root.panelWidth - root.contentMargin * 2
            implicitHeight: Math.max(contentLayout.implicitHeight, 300)

            MouseArea {
                anchors.fill: parent
                visible: root.showMenu
                z: 0
                onClicked: root.closeMenu()
                onPressed: root.closeMenu()
            }

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 0
                z: 1
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
                                };
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
                                                var subY = menuContent.y + 4 + root.menuSelectedIndex * root.itemHeight - menuFlick.contentY;
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
                                            var subY = menuContent.y + 4 + root.menuSelectedIndex * root.itemHeight - menuFlick.contentY;
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
                                        var cx = root.iconCenterX(root.trayIndex);
                                        root.openMenuItem(item, cx);
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

                        var itemH = root.itemHeight;
                        var itemY = root.menuSelectedIndex * itemH;
                        if (itemY < menuFlick.contentY)
                            menuFlick.contentY = itemY;
                        else if (itemY + itemH > menuFlick.contentY + menuFlick.height)
                            menuFlick.contentY = itemY + itemH - menuFlick.height;
                    }

                    function onSubmenuSelectedIndexChanged() {
                        if (!root.showSubmenu || root.submenuSelectedIndex < 0 || !submenuFlick)
                            return ;

                        var itemH = root.itemHeight;
                        var itemY = root.submenuSelectedIndex * itemH;
                        if (itemY < submenuFlick.contentY)
                            submenuFlick.contentY = itemY;
                        else if (itemY + itemH > submenuFlick.contentY + submenuFlick.height)
                            submenuFlick.contentY = itemY + itemH - submenuFlick.height;
                    }

                target: root
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        id: trayBar

                        Layout.fillWidth: true
                        height: 34
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.primary

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
                                            var cp = trayIconItem.mapToItem(contentLayout, mouse.x, 0);
                                            if (mouse.button === Qt.RightButton) {
                                                if (modelData.hasMenu)
                                                    root.openMenuItem(modelData, cp.x);
                                            } else {
                                                if (modelData.hasMenu && modelData.onlyMenu)
                                                    root.openMenuItem(modelData, cp.x);
                                                else {
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
                    clip: true
                    z: 10
                    anchors.top: trayBar.top
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
                                        onEntered: {
                                            if (modelData.enabled && !modelData.isSeparator) {
                                                root.menuSelectedIndex = index;
                                                submenuHoverTimer.stop();
                                                if (modelData.hasChildren) {
                                                    submenuHoverTimer.targetIndex = index;
                                                    submenuHoverTimer.restart();
                                                } else {
                                                    submenuHoverTimer.targetIndex = -1;
                                                    root.closeSubmenu();
                                                }
                                            }
                                        }
                                        onExited: {
                                            if (submenuHoverTimer.targetIndex === index)
                                                submenuHoverTimer.stop();
                                        }
                                        onClicked: {
                                            if (modelData.enabled && !modelData.isSeparator) {
                                                submenuHoverTimer.stop();
                                                if (modelData.hasChildren) {
                                                    var subX = menuContent.x + menuContent.width;
                                                    var subY = menuContent.y + 4 + index * root.itemHeight - menuFlick.contentY;
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
                    clip: true
                    z: 11
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
                                        onEntered: {
                                            if (modelData.enabled && !modelData.isSeparator)
                                                root.submenuSelectedIndex = index;

                                        }
                                        onClicked: {
                                            if (modelData.enabled && !modelData.isSeparator) {
                                                if (modelData.hasChildren) {
                                                    var subX = submenuContent.x + submenuContent.width;
                                                    var subY = submenuContent.y + 4 + index * root.itemHeight - submenuFlick.contentY;
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

            }

        }

    }

}
