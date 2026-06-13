import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool dnd: false
    property var toastModel

    toastModel: ListModel {
    }

    property var centerPopup: null
    property var service: null
}
