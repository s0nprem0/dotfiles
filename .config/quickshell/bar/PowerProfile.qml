import "../components"
import "../service"
import QtQuick
import Quickshell
import Quickshell.Io

BarModule {
    id: root

    property string activeProfile: "balanced"
    property var availableProfiles: ["balanced", "power-saver", "performance"]
    property int profileIndex: 1
    readonly property var profileMeta: ({
        "performance": {
            "icon": "",
            "color": Theme.error
        },
        "balanced": {
            "icon": "",
            "color": Theme.fg
        },
        "power-saver": {
            "icon": "",
            "color": Theme.green
        }
    })

    function cycleProfile() {
        var next = (root.profileIndex + 1) % root.availableProfiles.length;
        var profile = root.availableProfiles[next];
        setProfileProc.command = [Theme.bin("set_power_profile.sh"), profile];
        setProfileProc.running = true;
    }

    implicitWidth: profileText.implicitWidth + 12
    acceptedButtons: Qt.LeftButton
    tooltipText: "Power Profile: " + root.activeProfile

    DataModule {
        id: powerData

        path: Theme.bin("get_power_profile")
        interval: 30000
        onDataReceived: function(j) {
            root.activeProfile = j.active ?? "balanced";
            root.availableProfiles = j.available ?? [root.activeProfile];
            root.profileIndex = root.availableProfiles.indexOf(root.activeProfile);
            if (root.profileIndex < 0)
                root.profileIndex = 0;

        }
    }

    Binding {
        target: root
        property: "error"
        value: powerData.hasError
    }

    Binding {
        target: root
        property: "loading"
        value: powerData.loading
    }

    Process {
        id: setProfileProc
    }

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.cycleProfile();

        }

        target: mA
    }

    Connections {
        function onRunningChanged() {
            if (!setProfileProc.running)
                powerData.refresh();

        }

        target: setProfileProc
    }

    Text {
        id: profileText

        anchors.centerIn: parent
        text: {
            var m = root.profileMeta[root.activeProfile];
            return (m ? m.icon : "") + " " + root.activeProfile;
        }
        color: {
            var m = root.profileMeta[root.activeProfile];
            return m ? m.color : Theme.fg;
        }
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

}
