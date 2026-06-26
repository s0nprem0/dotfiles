import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool dnd: false
    property ListModel toastModel
    property var centerPopup: null
    property var service: null

    toastModel: ListModel {
    }

}
