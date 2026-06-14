import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PopupPanel {
    id: root

    // ── Hyprland state ──
    property var windowList: []
    property var windowByAddress: ({})
    property var activeWorkspaceId: 1
    property var monitors: []
    property var monitorById: ({})
    property string activeWindowAddress: ""
    property var visibleWorkspaceIds: [1]
    // ── Drag state ──
    property string draggedAddress: ""
    property int draggedSourceWorkspace: -1
    property bool dragActive: false
    property real dragX: 0
    property real dragY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property int hoveredWorkspaceId: -1
    property bool dragMoved: false

    // ── Config ──
    anchorSide: "none"
    panelWidth: 720
    panelMaxHeight: 0
    finalInset: 12
    contentMargin: 8
    onBeforeOpen: updateAll()

    // ── Helpers ──
    function toRoman(num) {
        var lookup = { 1: "i", 2: "ii", 3: "iii", 4: "iv", 5: "v", 6: "vi", 7: "vii", 8: "viii", 9: "ix", 10: "x" };
        return lookup[num] || String(num);
    }

    function normalizeAddress(address) {
        if (!address) return "";
        var s = String(address).toLowerCase();
        if (!s.startsWith("0x")) s = "0x" + s;
        return s;
    }

    function rebuildVisibleWorkspaceIds() {
        var map = {};
        var activeId = Math.max(1, root.activeWorkspaceId);
        var maxId = activeId;
        map[activeId] = true;
        for (var i = 0; i < root.windowList.length; i++) {
            var win = root.windowList[i];
            var wsId = (win && win.workspace) ? win.workspace.id : -1;
            if (wsId > 0) { map[wsId] = true; maxId = Math.max(maxId, wsId); }
        }
        if (maxId < 10) { map[maxId + 1] = true; maxId++; }
        else { map[9] = true; }
        var ids = [];
        for (var id = 1; id <= maxId; id++) { if (map[id]) ids.push(id); }
        root.visibleWorkspaceIds = ids.length > 0 ? ids : [1];
    }

    function getToplevelForAddress(address) {
        var values = ToplevelManager.toplevels.values;
        var targetAddr = root.normalizeAddress(address);
        for (var i = 0; i < values.length; i++) {
            var tl = values[i];
            if (tl.HyprlandToplevel) {
                var tlAddr = tl.HyprlandToplevel.address;
                var tlAddrStr = "";
                if (typeof tlAddr === "number") tlAddrStr = "0x" + tlAddr.toString(16);
                else {
                    tlAddrStr = String(tlAddr).toLowerCase();
                    if (!tlAddrStr.startsWith("0x")) tlAddrStr = "0x" + tlAddrStr;
                }
                if (tlAddrStr === targetAddr) return tl;
            }
        }
        return null;
    }

    function findHoveredWorkspace(container, globalX, globalY, repeater) {
        for (var i = 0; i < root.visibleWorkspaceIds.length; i++) {
            var cell = repeater.itemAt(i);
            if (cell) {
                var cp = container.mapToItem(cell, globalX, globalY);
                if (cp.x >= 0 && cp.x <= cell.width && cp.y >= 0 && cp.y <= cell.height)
                    return cell.wsId;
            }
        }
        return -1;
    }

    function getVisualGeometry(wsId, modelData, scale) {
        return {
            x: Math.round(modelData.at[0] * scale),
            y: Math.round(modelData.at[1] * scale),
            width: Math.max(Math.round(modelData.size[0] * scale), 12),
            height: Math.max(Math.round(modelData.size[1] * scale), 12),
            opacity: (root.dragActive && root.draggedAddress === modelData.address) ? 0.85 : 0.8
        };
    }

    function iconExists(iconName) {
        if (!iconName) return false;
        var path = Quickshell.iconPath(iconName, true);
        return path && path.length > 0 && !String(path).includes("image-missing");
    }

    function iconFromString(value) {
        if (!value) return "";
        var name = String(value);
        var entry = DesktopEntries.byId(name);
        if (entry && entry.icon && root.iconExists(entry.icon)) return entry.icon;
        var subs = {
            "code": "visual-studio-code", "code-url-handler": "visual-studio-code",
            "code-insiders": "visual-studio-code-insiders", "codium": "vscodium",
            "footclient": "foot", "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome", "kitty": "kitty",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "steam": "steam", "thunar": "org.xfce.thunar",
            "vesktop": "vesktop", "wezterm": "org.wezfurlong.wezterm",
            "zen": "zen-browser"
        };
        var lower = name.toLowerCase();
        if (subs[name] && root.iconExists(subs[name])) return subs[name];
        if (subs[lower] && root.iconExists(subs[lower])) return subs[lower];
        if (root.iconExists(name)) return name;
        if (root.iconExists(lower)) return lower;
        var last = name.split(".").pop();
        if (root.iconExists(last)) return last;
        if (root.iconExists(last.toLowerCase())) return last.toLowerCase();
        var kebab = lower.replace(/\s+/g, "-").replace(/_/g, "-");
        if (root.iconExists(kebab)) return kebab;
        var heur = DesktopEntries.heuristicLookup(name);
        if (heur && heur.icon && root.iconExists(heur.icon)) return heur.icon;
        return "";
    }

    function getWindowIconPath(win) {
        var candidates = [win ? win.class : "", win ? win.initialClass : "", win ? win.initialTitle : "", win ? win.title : ""];
        for (var i = 0; i < candidates.length; i++) {
            var iconName = root.iconFromString(candidates[i]);
            if (iconName) return iconName.startsWith("/") ? "file://" + iconName : "image://icon/" + iconName;
        }
        return "image://icon/application-x-executable";
    }

    function updateAll() {
        getClients.running = true;
        getMonitors.running = true;
        getActiveWorkspace.running = true;
        getActiveWindow.running = true;
    }

    // ── Hyprctl processes ──
    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.windowList = parsed;
                    var temp = {};
                    for (var i = 0; i < parsed.length; i++) {
                        var win = parsed[i];
                        win.address = root.normalizeAddress(win.address);
                        temp[win.address] = win;
                    }
                    root.windowByAddress = temp;
                    root.rebuildVisibleWorkspaceIds();
                } catch (e) { console.warn("Workspace: clients parse error", e); }
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.monitors = parsed;
                    var temp = {};
                    for (var i = 0; i < parsed.length; i++) temp[parsed[i].id] = parsed[i];
                    root.monitorById = temp;
                } catch (e) { console.warn("Workspace: monitors parse error", e); }
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.activeWorkspaceId = JSON.parse(this.text).id;
                    root.rebuildVisibleWorkspaceIds();
                } catch (e) {}
            }
        }
    }

    Process {
        id: getActiveWindow
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.activeWindowAddress = root.normalizeAddress(JSON.parse(this.text).address); }
                catch (e) { root.activeWindowAddress = ""; }
            }
        }
    }

    // ── Live refresh on Hyprland events ──
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            if (root.showPopup) updateAll();
        }
    }

    // ── Content ──
    contentComponent: Component {
        Item {
            id: contentRoot

            implicitWidth: wsGrid.implicitWidth
            implicitHeight: wsGrid.implicitHeight

            GridLayout {
                id: wsGrid

                columns: Math.min(root.visibleWorkspaceIds.length, 4)
                rowSpacing: 10
                columnSpacing: 10
                anchors.centerIn: parent

                Repeater {
                    id: wsGridRepeater

                    model: root.visibleWorkspaceIds.length

                    delegate: Rectangle {
                        id: wsCell

                        readonly property int wsId: root.visibleWorkspaceIds[index]
                        readonly property bool isActive: root.activeWorkspaceId === wsId

                        implicitWidth: 166
                        implicitHeight: 100
                        color: root.hoveredWorkspaceId === wsId ? Qt.alpha(Theme.primary, 0.18) : isActive ? Qt.alpha(Theme.primary, 0.1) : Qt.alpha(Theme.surface, 0.5)
                        radius: 6
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? Qt.alpha(Theme.primary, 0.4) : "transparent"
                        scale: root.hoveredWorkspaceId === wsId && root.dragActive ? 1.04 : 1

                        // ── Roman numeral badge ──
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -4
                            anchors.rightMargin: -4
                            width: Math.max(16, badgeText.implicitWidth + 6)
                            height: 16
                            radius: 4
                            color: isActive ? Theme.primary : Theme.surface
                            border.width: 1
                            border.color: isActive ? Theme.primary : Qt.alpha(Theme.primary, 0.3)
                            z: 10

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.toRoman(wsCell.wsId)
                                color: isActive ? Theme.bg : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        // ── Click to switch ──
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.dragActive
                            onClicked: {
                                Hyprland.dispatch("workspace", String(wsCell.wsId));
                                root.closePopup();
                            }
                        }

                        // ── Drop target ──
                        DropArea {
                            anchors.fill: parent
                            onEntered: root.hoveredWorkspaceId = wsCell.wsId
                            onExited: { if (root.hoveredWorkspaceId === wsCell.wsId) root.hoveredWorkspaceId = -1; }
                        }

                        // ── Window previews ──
                        Item {
                            id: previewContainer

                            readonly property real monitorW: 1920
                            readonly property real monitorH: 1080
                            readonly property real scaleX: width / monitorW
                            readonly property real scaleY: height / monitorH
                            readonly property real scale: Math.min(scaleX, scaleY)

                            anchors.fill: parent
                            anchors.margins: 2
                            clip: true

                            Repeater {
                                model: root.windowList.filter(function(w) { return w.workspace && w.workspace.id === wsCell.wsId; })

                                delegate: Rectangle {
                                    id: winPreview

                                    required property var modelData

                                    x: root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address) ? root.dragX : root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).x
                                    y: root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address) ? root.dragY : root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).y
                                    width: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).width
                                    height: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).height
                                    color: "transparent"
                                    border.width: root.activeWindowAddress === root.normalizeAddress(modelData.address) ? 1 : 0
                                    border.color: Theme.primary
                                    radius: 2
                                    clip: true
                                    opacity: root.getVisualGeometry(wsCell.wsId, modelData, previewContainer.scale).opacity
                                    scale: root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address) ? 0.95 : 1
                                    z: root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address) ? 9999 : 1

                                    // ── Live screencopy ──
                                    Loader {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        active: true

                                        sourceComponent: ScreencopyView {
                                            captureSource: root.getToplevelForAddress(winPreview.modelData.address)
                                            live: true
                                            width: Math.max(Math.round(winPreview.modelData.size[0] * previewContainer.scale), 12)
                                            height: Math.max(Math.round(winPreview.modelData.size[1] * previewContainer.scale), 12)
                                            constraintSize: Qt.size(width, height)
                                        }
                                    }

                                    // ── App icon overlay ──
                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 3
                                        color: Qt.alpha(Theme.bg, 0.7)
                                        anchors.centerIn: parent

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            fillMode: Image.PreserveAspectFit
                                            source: root.getWindowIconPath(winPreview.modelData)
                                        }
                                    }

                                    // ── Drag handle ──
                                    MouseArea {
                                        id: dragHandle

                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onPressed: function(mouse) {
                                            root.draggedAddress = root.normalizeAddress(winPreview.modelData.address);
                                            root.draggedSourceWorkspace = wsCell.wsId;
                                            root.dragActive = true;
                                            root.dragMoved = false;
                                            var pt = mapToItem(contentRoot, mouse.x, mouse.y);
                                            root.dragOffsetX = mouse.x;
                                            root.dragOffsetY = mouse.y;
                                            root.dragX = pt.x - mouse.x;
                                            root.dragY = pt.y - mouse.y;
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (pressed) {
                                                var pt = mapToItem(contentRoot, mouse.x, mouse.y);
                                                root.dragX = pt.x - root.dragOffsetX;
                                                root.dragY = pt.y - root.dragOffsetY;
                                                root.dragMoved = true;
                                                root.hoveredWorkspaceId = root.findHoveredWorkspace(contentRoot, pt.x, pt.y, wsGridRepeater);
                                            }
                                        }

                                        onReleased: function(mouse) {
                                            var targetWs = root.hoveredWorkspaceId;
                                            if (root.dragActive) {
                                                root.dragActive = false;
                                                if (targetWs !== -1 && targetWs !== root.draggedSourceWorkspace) {
                                                    Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", String(targetWs) + ",address:" + root.draggedAddress]);
                                                    root.updateAll();
                                                }
                                            }
                                            root.draggedAddress = "";
                                            root.draggedSourceWorkspace = -1;
                                            root.hoveredWorkspaceId = -1;
                                        }

                                        onCanceled: {
                                            root.dragActive = false;
                                            root.draggedAddress = "";
                                            root.draggedSourceWorkspace = -1;
                                            root.hoveredWorkspaceId = -1;
                                        }

                                        onClicked: function(mouse) {
                                            if (root.dragMoved) return;
                                            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + root.normalizeAddress(winPreview.modelData.address)]);
                                            root.closePopup();
                                        }
                                    }

                                    // ── Tooltip ──
                                    Rectangle {
                                        id: tooltip
                                        visible: dragHandle.containsMouse && !root.dragActive && winPreview.modelData.title
                                        z: 99999
                                        x: (winPreview.width - width) / 2
                                        y: winPreview.height + 4
                                        width: Math.min(tooltipText.implicitWidth + 8, 200)
                                        height: tooltipText.implicitHeight + 4
                                        radius: 3
                                        color: Qt.alpha(Theme.surface, 0.95)
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.primary, 0.2)

                                        Text {
                                            id: tooltipText
                                            anchors.centerIn: parent
                                            text: winPreview.modelData.title
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            width: parent.width - 8
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    Behavior on x { enabled: !(root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address)); NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on y { enabled: !(root.dragActive && root.draggedAddress === root.normalizeAddress(modelData.address)); NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 180 } }
                                }
                            }

                            // ── Empty workspace text ──
                            Text {
                                anchors.centerIn: parent
                                text: "empty"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                opacity: 0.5
                                visible: {
                                    var count = 0;
                                    for (var i = 0; i < root.windowList.length; i++) {
                                        if (root.windowList[i].workspace && root.windowList[i].workspace.id === wsCell.wsId)
                                            count++;
                                    }
                                    return count === 0;
                                }
                            }
                        }

                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
