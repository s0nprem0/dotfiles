import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool dnd: false
    property ListModel toastModel: ListModel { }

    property var centerPopup: null
    property var service: null
}
