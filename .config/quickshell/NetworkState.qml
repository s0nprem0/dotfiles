pragma Singleton
import QtQuick

QtObject {
    id: root

    property var popup: null
    property var networkData: null
    signal refreshRequested()
}
