import QtQuick
import Quickshell.Io

Item {
    id: root

    property string cachePrefix: "art_"
    property string pendingUrl: ""

    signal cacheReady(string url, string localPath)

    function ensureCached(url) {
        if (!url || url.indexOf("://") === -1) return
        if (url.indexOf("file://") === 0) return
        if (url === root.pendingUrl) return
        root.pendingUrl = url
        cacheProc.command = ["sh", "-c",
            "url=\"$1\"\n" +
            "hash=$(echo \"$url\" | md5sum | cut -c1-16)\n" +
            "path=\"/tmp/" + root.cachePrefix + "$hash\"\n" +
            "find /tmp/" + root.cachePrefix + "* -mmin +60 -delete 2>/dev/null\n" +
            "[ -f \"$path\" ] || curl -sL -o \"$path\" \"$url\"\n" +
            "echo \"$url|$path\"",
            "_", url]
        cacheProc.running = true
    }

    Process {
        id: cacheProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            var output = stdout.text.trim()
            if (output) {
                var parts = output.split("|")
                if (parts.length === 2 && parts[0] === root.pendingUrl)
                    root.cacheReady(parts[0], "file://" + parts[1])
            }
        }
    }
}