import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    required property var notification
    property bool closed: false
    property bool popup: false
    property bool unread: true
    property date time: new Date()
    property real timestamp: time.getTime()
    property string timeStr: "now"
    property string id
    property string summary
    property string body
    property string appIcon
    property string appName
    property string image
    property int urgency: NotificationUrgency.Normal
    property real expireTimeout: 0
    property var actions: []
    property var hints: ({
    })
    property real snoozeUntil: 0

    function updateTimeStr() {
        var diff = Date.now() - root.time.getTime();
        var m = Math.floor(diff / 60000);
        if (m < 1) {
            root.timeStr = "now";
        } else if (m < 60) {
            root.timeStr = m + "m";
        } else {
            var h = Math.floor(m / 60);
            if (h < 24)
                root.timeStr = h + "h";
            else
                root.timeStr = Math.floor(h / 24) + "d";
        }
    }

    function close() {
        if (root.closed)
            return ;

        root.closed = true;
        if (root.notification)
            root.notification.dismiss();

    }

    function invokeAction(actionId) {
        if (root.notification && !root.closed)
            root.notification.invoke(actionId);

    }

    function snooze(ms) {
        root.snoozeUntil = Date.now() + ms;
        root.closed = true;
        if (root.notification)
            root.notification.dismiss();

        snoozeTimer.interval = ms;
        snoozeTimer.restart();
    }

    function mapActions(actionList) {
        var acts = [];
        for (var i = 0; i < actionList.length; i++) {
            var a = actionList[i];
            var invokeFn = (function(act) {
                return function() {
                    act.invoke();
                };
            })(a);
            acts.push({
                "identifier": a.identifier,
                "label": a.label,
                "invoke": invokeFn
            });
        }
        return acts;
    }

    Component.onCompleted: {
        if (!root.notification)
            return ;

        root.notification.tracked = true;
        root.id = root.notification.id;
        root.summary = root.notification.summary;
        root.body = root.notification.body;
        root.appIcon = root.notification.appIcon;
        root.appName = root.notification.appName;
        root.image = root.notification.image;
        root.urgency = root.notification.urgency;
        root.expireTimeout = root.notification.expireTimeout;
        root.hints = root.notification.hints;
        root.actions = mapActions(root.notification.actions);
        root.timestamp = root.time.getTime();
    }

    Timer {
        id: snoozeTimer

        onTriggered: {
            root.closed = false;
            root.snoozeUntil = 0;
        }
    }

    Connections {
        function onClosed() {
            root.closed = true;
        }

        function onSummaryChanged() {
            root.summary = root.notification.summary;
        }

        function onBodyChanged() {
            root.body = root.notification.body;
        }

        function onAppIconChanged() {
            root.appIcon = root.notification.appIcon;
        }

        function onAppNameChanged() {
            root.appName = root.notification.appName;
        }

        function onUrgencyChanged() {
            root.urgency = root.notification.urgency;
        }

        function onExpireTimeoutChanged() {
            root.expireTimeout = root.notification.expireTimeout;
        }

        function onActionsChanged() {
            root.actions = mapActions(root.notification.actions);
        }

        target: root.notification
    }

}
