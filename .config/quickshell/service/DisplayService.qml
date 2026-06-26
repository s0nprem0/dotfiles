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
    property var monitorsById: ({
    })
    property int monitorCount: 0
    property string primaryMonitorId: ""
    property bool isLoading: false
    property string currentMode: "extend"
    property bool initialized: false
    property var profiles: ({
    })
    property string activeProfile: ""
    readonly property string monitorSettingsPath: "file://" + Theme.cacheDir + "/monitor_settings.json"

    signal monitorsDataChanged()
    signal modeChanged()
    signal primaryMonitorChanged()

    function refreshMonitors() {
        if (root.isLoading)
            return ;

        root.isLoading = true;
        monitorProc.running = true;
    }

    function getMonitor(id) {
        return root.monitorsById[id] || null;
    }

    function getAnyScreen() {
        if (root.monitorCount > 0 && root.monitors.length > 0)
            return root.monitors[0];

        return null;
    }

    function updateCurrentMode() {
        var internalOn = false;
        var externalOn = false;
        for (var i = 0; i < root.monitors.length; i++) {
            var m = root.monitors[i];
            if (m.disabled)
                continue;

            if (m.name.startsWith("eDP") || m.name.startsWith("DSI") || m.name.startsWith("LVDS") || m.name.startsWith("OLED"))
                internalOn = true;
            else
                externalOn = true;
        }
        var newMode = "extend";
        if (!internalOn && externalOn)
            newMode = "external";
        else if (internalOn && externalOn)
            newMode = "extend";
        else if (internalOn && !externalOn)
            newMode = "internal";
        if (newMode !== root.currentMode) {
            root.currentMode = newMode;
            root.modeChanged();
        }
    }

    function loadProfiles() {
        try {
            var data = JSON.parse(profilesFile.text || "{}");
            root.profiles = data.profiles || {
            };
            root.activeProfile = data.activeProfile || "";
        } catch (e) {
            root.profiles = {
            };
        }
    }

    function saveProfiles() {
        var data = {
            "profiles": root.profiles,
            "activeProfile": root.activeProfile
        };
        stateFile.write(JSON.stringify(data, null, 2));
    }

    function getMonitorScale(name) {
        var config = loadMonitorSettings();
        return config[name] && config[name].scale || 1;
    }

    function setMonitorScale(name, scale) {
        var config = loadMonitorSettings();
        if (!config[name])
            config[name] = {
        };

        config[name].scale = scale;
        saveMonitorSettings(config);
    }

    function getMonitorTransform(name) {
        var config = loadMonitorSettings();
        return config[name] && config[name].transform || 0;
    }

    function setMonitorTransform(name, transform) {
        var config = loadMonitorSettings();
        if (!config[name])
            config[name] = {
        };

        config[name].transform = transform;
        saveMonitorSettings(config);
    }

    function getLogicalGeometry(monitor) {
        if (!monitor)
            return {
            "x": 0,
            "y": 0,
            "width": 1920,
            "height": 1080
        };

        return {
            "x": Math.round(monitor.x / monitor.scale),
            "y": Math.round(monitor.y / monitor.scale),
            "width": Math.round(monitor.width / monitor.scale),
            "height": Math.round(monitor.height / monitor.scale)
        };
    }

    function getLogicalPrimaryGeometry() {
        if (!root.primaryMonitorId)
            return {
            "x": 0,
            "y": 0,
            "width": 1920,
            "height": 1080
        };

        var monitor = root.getMonitor(root.primaryMonitorId);
        if (!monitor)
            return {
            "x": 0,
            "y": 0,
            "width": 1920,
            "height": 1080
        };

        return root.getLogicalGeometry(monitor);
    }

    function loadMonitorSettings() {
        try {
            return JSON.parse(monitorSettingsFile.text || "{}");
        } catch (e) {
            console.warn("DisplayService: Failed to parse monitor settings:", e);
            return {
            };
        }
    }

    function saveMonitorSettings(config) {
        try {
            monitorSettingsFile.write(JSON.stringify(config, null, 2));
        } catch (e) {
            console.warn("DisplayService: Failed to save monitor settings:", e);
        }
    }

    function applyProfile(profileName) {
        var profile = root.profiles[profileName];
        if (!profile)
            return false;

        root.activeProfile = profileName;
        saveProfiles();
        root.refreshMonitors();
        return true;
    }

    function createProfile(name, description, mode) {
        var profile = {
            "name": name,
            "description": description || "",
            "mode": mode || "extend",
            "monitors": {
            }
        };
        root.profiles[name] = profile;
        saveProfiles();
    }

    Component.onCompleted: {
        refreshMonitors();
    }
    onActiveProfileChanged: saveProfiles()

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
                    var temp = {
                    };
                    for (var i = 0; i < data.length; i++) {
                        temp[data[i].id] = data[i];
                    }
                    root.monitorsById = temp;
                    var newPrimaryId = "";
                    for (var j = 0; j < data.length; j++) {
                        if (data[j].focused) {
                            newPrimaryId = data[j].id;
                            break;
                        }
                    }
                    if (newPrimaryId !== root.primaryMonitorId) {
                        root.primaryMonitorId = newPrimaryId;
                        root.primaryMonitorChanged();
                    }
                    updateCurrentMode();
                    loadProfiles();
                    root.monitorsDataChanged();
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

    FileView {
        id: monitorSettingsFile

        path: root.monitorSettingsPath
        watchChanges: true
    }

    Connections {
        function onMonitorAdded() {
            console.log("DisplayService: monitor added, refreshing");
            root.refreshMonitors();
        }

        function onMonitorRemoved() {
            console.log("DisplayService: monitor removed, refreshing");
            root.refreshMonitors();
        }

        function onMonitorLayoutChanged() {
            console.log("DisplayService: monitor layout changed, refreshing");
            root.refreshMonitors();
        }

        target: Hyprland
    }

}
