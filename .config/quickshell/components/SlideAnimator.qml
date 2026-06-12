import QtQuick

Item {
    id: root

    property real slideFrom: -50
    property real slideTo: 5
    property int introDuration: 120
    property int exitDuration: 100
    property bool show: false
    property bool closing: false
    readonly property bool active: introAnim.running || exitAnim.running
    property real animSlide: slideFrom
    property real animOpacity: 0

    signal introStarting()
    signal introCompleted()
    signal exitCompleted()

    function closeAnim() {
        if (closing)
            return ;

        closing = true;
        show = false;
        exitAnim.start();
    }

    function forceFinish() {
        introAnim.stop();
        exitAnim.stop();
        animSlide = slideFrom;
        animOpacity = 0;
        show = false;
        closing = false;
    }

    visible: false
    onShowChanged: {
        if (show) {
            exitAnim.stop();
            closing = false;
            animSlide = slideFrom;
            animOpacity = 0;
            introStarting();
            introAnim.start();
        } else if (!closing) {
            introAnim.stop();
            closeAnim();
        }
    }

    ParallelAnimation {
        id: introAnim

        onStopped: {
            if (!root.closing)
                root.introCompleted();

        }

        NumberAnimation {
            target: root
            property: "animSlide"
            from: root.slideFrom
            to: root.slideTo
            duration: root.introDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "animOpacity"
            from: 0
            to: 1
            duration: root.introDuration
            easing.type: Easing.OutCubic
        }

    }

    ParallelAnimation {
        id: exitAnim

        onStopped: root.exitCompleted()

        NumberAnimation {
            target: root
            property: "animSlide"
            from: root.slideTo
            to: root.slideFrom
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "animOpacity"
            from: 1
            to: 0
            duration: root.exitDuration
            easing.type: Easing.InCubic
        }

    }

}
