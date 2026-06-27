import "../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var modelData
    required property int index

    property bool isSelected: false
    property int itemHeight: 22

    signal clicked()
    signal hovered()
    signal exited()

    anchors.left: parent.left
    anchors.right: parent.right
    height: modelData.isSeparator ? 6 : root.itemHeight
    color: {
        if (modelData.isSeparator)
            return "transparent";

        if (hoverHandler.containsMouse || root.isSelected)
            return Theme.primaryAlpha015;

        return "transparent";
    }

    Rectangle {
        visible: modelData.isSeparator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.muted
    }

    RowLayout {
        visible: !modelData.isSeparator
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 6

        Text {
            width: 12
            text: {
                if (modelData.buttonType === 1 || modelData.buttonType === 2)
                    return modelData.checkState === Qt.Checked ? "✓" : "";

                if (modelData.icon)
                    return "";

                return "";
            }
            color: Theme.fg
            font.pixelSize: Theme.fontSizeSm
            horizontalAlignment: Text.AlignHCenter
        }

        Image {
            width: 12
            height: 12
            source: modelData.icon
            visible: modelData.icon !== "" && status !== Image.Error
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 12
            sourceSize.height: 12
        }

        Text {
            text: modelData.text.replace(/&/g, "")
            color: modelData.enabled ? Theme.fg : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMd
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: "▸"
            visible: modelData.hasChildren
            color: modelData.enabled ? Theme.fg : Theme.muted
            font.pixelSize: Theme.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }

    }

    MouseArea {
        id: hoverHandler

        anchors.fill: parent
        hoverEnabled: modelData.enabled && !modelData.isSeparator
        acceptedButtons: Qt.LeftButton
        onEntered: {
            if (modelData.enabled && !modelData.isSeparator)
                root.hovered();

        }
        onExited: root.exited()
        onClicked: {
            if (modelData.enabled && !modelData.isSeparator)
                root.clicked();

        }
    }

}
