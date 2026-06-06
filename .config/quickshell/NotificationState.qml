pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool dnd: false
    property var expandedNotifIds: ({})
    property var toastModel: ListModel {}
    property var centerPopup: null
    property var networkPopup: null
    property var service: null
    property var server: null
}
