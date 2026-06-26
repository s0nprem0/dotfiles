import "../components"
import "../service"
import QtQuick
import Quickshell

BarModule {
    id: root

    property var emojiPopupRef: null

    implicitWidth: emojiText.implicitWidth + 12
    acceptedButtons: Qt.LeftButton
    tooltipText: "Emoji Picker"

    Connections {
        function onClicked(mouse) {
            if (root.emojiPopupRef)
                root.emojiPopupRef.showPopup = !root.emojiPopupRef.showPopup;

        }

        target: mA
    }

    Text {
        id: emojiText

        anchors.centerIn: parent
        text: "󰞍"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
    }

}
