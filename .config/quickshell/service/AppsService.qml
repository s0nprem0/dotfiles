import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    // Initialize with the new expected Rust JSON structure
    property var rawData: {
        "most_used": [],
        "all_apps": [],
        "web_history": [],
        "file_history": []
    }
    property bool isLoaded: false
    property Process appProc

    function refresh() {
        appProc.running = true;
    }

    Component.onCompleted: {
        refresh();
    }

    appProc: Process {
        command: [Theme.bin("get_apps_list")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rawData = JSON.parse(this.text || "{}");
                    root.isLoaded = true;
                } catch (e) {
                    console.error("Quickshell AppsService Error: Failed to parse Rust binary output.");
                }
            }
        }

    }

}
