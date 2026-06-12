import "../service"
import QtQuick

Row {
    property double currentVal: 0
    property int totalBlocks: 15
    property color fillColor: Theme.primary
    property color emptyColor: Theme.surfaceLighter

    spacing: 1
    height: 5

    Repeater {
        model: totalBlocks

        delegate: Rectangle {
            required property int index

            height: parent.height
            width: (parent.width - (parent.spacing * (parent.totalBlocks - 1))) / parent.totalBlocks
            radius: 0
            color: index < Math.round(parent.currentVal * parent.totalBlocks) ? parent.fillColor : parent.emptyColor
        }

    }

}
