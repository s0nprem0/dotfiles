pragma Singleton
import QtQuick

QtObject {
    id: root

    property var activeNotifs: []
    property var historyNotifs: []
    property bool historyExpanded: false
    property bool dnd: false
    property var expandedNotifIds: ({})
    property var toastModel: ListModel {}
    property var centerPopup: null
    property var service: null
}
