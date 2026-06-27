import "../service"
import QtQuick

Row {
    id: root

    property string icon: ""
    property string text: ""
    property bool small: false

    spacing: 6

    Text {
        text: root.icon
        visible: root.icon.length > 0
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: root.small ? Theme.fontSizeSm : Theme.fontSizeXl
        font.bold: true
    }

    Text {
        text: root.text
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: root.small ? Theme.fontSizeSm : Theme.fontSizeXl
        font.bold: true
        opacity: root.small ? 0.5 : 1
    }

}
