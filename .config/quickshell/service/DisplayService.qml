import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

Item {
    id: root

    readonly property string statePath: "file://" + Theme.cacheDir + "/display_state.json"
    readonly property string profilesPath: "file://" + Theme.cacheDir + "/display_profiles.json"

    property var monitors: []
    property var monitorsById: ({})
    property int monitorCount: 0
    property string primaryMonitorId: ""
    property bool isLoading: false
    property string currentMode: "extend"
    property bool initialized: false

    property var profiles: ({})
    property string activeProfile: ""

    Process {
        id: monitorProc

        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.monitors = data;
                    root.monitorCount = data.length;

                    var temp = {};
                    for (var i = 0; i < data.length; i++) {
                        temp[data[i].id] = data[i];
                    }
                    root.monitorsById = temp;

                    root.primaryMonitorId = "";
                    for (var j = 0; j < data.length; j++) {
                        if (data[j].focused) {
                            root.primaryMonitorId = data[j].id;
                            break;
                        }
                    }

                    updateCurrentMode();
                    loadProfiles();
                } catch (e) {
                    console.warn("DisplayService: Failed to parse monitors:", e);
                }
                root.isLoading = false;
            }
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onLoaded: {
            try {
                var data = JSON.parse(this.text || "{}");
                root.activeProfile = data.activeProfile || "";
            } catch (e) {
                console.warn("DisplayService: Failed to parse state:", e);
            }
        }
    }

    FileView {
        id: profilesFile
        path: root.profilesPath
        watchChanges: true
        onLoaded: {
            try {
                root.profiles = JSON.parse(this.text || "{}");
            } catch (e) {
                console.warn("DisplayService: Failed to parse profiles:", e);
            }
        }
    }

    function refreshMonitors() {
        if (root.isLoading) return;
        root.isLoading = true;
        monitorProc.running = true;
    }

    function getMonitor(id) {
        return root.monitorsById[id] || null;
    }

    function getAnyScreen() {
        if (root.monitorCount > 0 && root.monitors.length > 0) {
            return root.monitors[0];
        }
        return null;
    }

    function updateCurrentMode() {
        var internalOn = false;
        var externalOn = false;

        for (var i = 0; i < root.monitors.length; i++) {
            var m = root.monitors[i];
            if (m.disabled) continue;

            if (m.name.startsWith("eDP") || m.name.startsWith("DSI") || 
                m.name.startsWith("LVDS") || m.name.startsWith("OLED")) {
                internalOn = true;
            } else {
                externalOn = true;
            }
        }

        if (!internalOn && externalOn) {
            root.currentMode = "external";
        } else if (internalOn && externalOn) {
            root.currentMode = "extend";
        } else if (internalOn && !externalOn) {
            root.currentMode = "internal";
        } else {
            root.currentMode = "extend";
        }
    }

    function loadProfiles() {
        try {
            var data = JSON.parse(profilesFile.text || "{}");
            root.profiles = data.profiles || {};
            root.activeProfile = data.activeProfile || "";
        } catch (e) {
            root.profiles = {};
        }
    }

    function saveProfiles() {
        var data = {
            profiles: root.profiles,
            activeProfile: root.activeProfile
        };
        stateFile.write(JSON.stringify(data, null, 2));
    }

    Connections {
        target: Hyprland
        function onMonitorAdded() { root.refreshMonitors() }
        function onMonitorRemoved() { root.refreshMonitors() }
        function onMonitorLayoutChanged() { root.refreshMonitors() }
    }

    Component.onCompleted: {
        refreshMonitors();
        Theme.binChanged.connect(refreshMonitors);
    }

    onActiveProfileChanged: saveProfiles();
}

/*
Usage:
- DisplayService.monitors - Array of all monitors
- DisplayService.monitorsById - Object lookup by monitor ID
- DisplayService.monitorCount - Number of monitors
- DisplayService.primaryMonitorId - ID of focused monitor
- DisplayService.currentMode - "extend"|"duplicate"|"external"|"internal"
- DisplayService.refreshMonitors() - Force refresh
- DisplayService.getMonitor(id) - Get monitor by ID
*/