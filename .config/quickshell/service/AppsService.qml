pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Initialize with the new expected Rust JSON structure
    property var rawData: { "most_used": [], "all_apps": [], "web_history": [], "file_history": [] }
    property bool isLoaded: false

    function refresh() {
        appProc.running = true;
    }

    property Process appProc: Process {
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

    Component.onCompleted: {
        refresh();
    }
}
