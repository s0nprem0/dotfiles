import Quickshell
import QtQuick
import "../components"
import "../service"

BarModule {
    id: root

    implicitWidth: emojiText.implicitWidth + 12

    property var emojiPopupRef: null

    acceptedButtons: Qt.LeftButton

    Connections {
        target: mA
        function onClicked(mouse) {
            if (root.emojiPopupRef)
                root.emojiPopupRef.showPopup = !root.emojiPopupRef.showPopup
        }
    }

    tooltipText: "Emoji Picker"

    Text {
        id: emojiText
        anchors.centerIn: parent
        text: "󰞍"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
