pragma Singleton
import QtQuick

QtObject {
    id: root

    property var server: null
    property var service: null
    property bool dnd: false
    property var toastModel: null
    property var centerPopup: null
}
