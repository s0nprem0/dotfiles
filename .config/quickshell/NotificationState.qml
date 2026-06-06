pragma Singleton
import QtQuick
import QtQml.Models

QtObject {
    id: root

    property bool dnd: false
    property var toastModel: ListModel {}
    property var notifList: []
    property var centerPopup: null
    property var service: null
    property var server: null
}
