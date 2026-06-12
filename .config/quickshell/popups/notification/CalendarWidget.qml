import "../../service"
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property int calendarMonthOffset: 0
    property bool showCalendar: true
    property string hourStr: ""
    property string minStr: ""
    property string secStr: ""
    property string ampmStr: ""
    property string uptimeStr: ""

    function getCalendarDays(offset) {
        var date = new Date();
        date.setMonth(date.getMonth() + offset);
        var year = date.getFullYear();
        var month = date.getMonth();
        var firstDay = new Date(year, month, 1);
        var startDayOfWeek = firstDay.getDay();
        var numDays = new Date(year, month + 1, 0).getDate();
        var numDaysPrev = new Date(year, month, 0).getDate();
        var days = [];
        for (var i = startDayOfWeek - 1; i >= 0; i--) days.push({
            "day": numDaysPrev - i,
            "isCurrentMonth": false,
            "isToday": false
        })
        var todayDate = new Date();
        for (var d = 1; d <= numDays; d++) {
            var isToday = (todayDate.getDate() === d && todayDate.getMonth() === month && todayDate.getFullYear() === year);
            days.push({
                "day": d,
                "isCurrentMonth": true,
                "isToday": isToday
            });
        }
        var remaining = 42 - days.length;
        for (var n = 1; n <= remaining; n++) days.push({
            "day": n,
            "isCurrentMonth": false,
            "isToday": false
        })
        return days;
    }

    spacing: 20

    ColumnLayout {
        id: calendarCol

        Layout.preferredWidth: 140
        spacing: 6

        RowLayout {
            spacing: 8

            Text {
                text: {
                    var date = new Date();
                    date.setMonth(date.getMonth() + root.calendarMonthOffset);
                    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                    return months[date.getMonth()] + " " + date.getFullYear();
                }
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.calendarMonthOffset = 0
                }

            }

            Text {
                text: ""
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                    onExited: parent.color = Theme.primary
                    onClicked: root.calendarMonthOffset -= 1
                }

            }

            Text {
                text: ""
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                    onExited: parent.color = Theme.primary
                    onClicked: root.calendarMonthOffset += 1
                }

            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.showCalendar ? "" : ""
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Theme.primary
                    onExited: parent.color = Theme.muted
                    onClicked: root.showCalendar = !root.showCalendar
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.showCalendar

            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]

                delegate: Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.primary
                    opacity: 0.5
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }

            }

        }

        GridLayout {
            Layout.fillWidth: true
            visible: root.showCalendar
            columns: 7
            rows: 6
            rowSpacing: 2
            columnSpacing: 0

            Repeater {
                model: root.getCalendarDays(root.calendarMonthOffset)

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 20
                    Layout.preferredHeight: 18
                    color: modelData.isToday ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.isToday ? Theme.bg : Theme.primary
                        opacity: modelData.isToday ? 1 : (modelData.isCurrentMonth ? 0.85 : 0.3)
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: modelData.isToday
                    }

                }

            }

        }

    }

    ColumnLayout {
        id: clockCol

        Layout.fillWidth: true
        spacing: 2
        Layout.alignment: Qt.AlignVCenter

        Text {
            text: root.hourStr
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 28
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.minStr
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 24
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: root.secStr
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Text {
                text: root.ampmStr
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

        }

        Item {
            height: 4
        }

        Text {
            text: root.uptimeStr
            color: Theme.primary
            opacity: 0.75
            font.family: Theme.fontFamily
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }

    }

}
