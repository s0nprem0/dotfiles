import QtQuick
pragma Singleton

QtObject {
    id: root

    property var popup: null
    property var networkData: null

    signal refreshRequested()
}
