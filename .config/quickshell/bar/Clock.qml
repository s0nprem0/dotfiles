import "../components"
import "../service"
import QtQuick

BarModule {
    id: root

    readonly property string dateFormat: "ddd MMM d HH:mm"

    implicitWidth: clockText.implicitWidth + 16
    tooltipText: ""

    Text {
        id: clockText

        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), root.dateFormat)
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        font.bold: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), root.dateFormat)
    }

    Connections {
        function onClicked(mouse) {
            if (NotificationState.centerPopup)
                NotificationState.centerPopup.showPopup = true;

        }

        target: mA
    }

}
