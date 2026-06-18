import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property var availableProfiles: []
    property int chargeLimit: 80
    property int currentBrightness: 80
    property int currentKbd: 50

    signal setProfile(string profile)
    signal brightnessChanged(int pct)
    signal kbdChanged(int pct)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        PowerCard {
            activeProfile: root.activeProfile
            chargeLimit: root.chargeLimit
            onProfileSelected: (p) => {
                return root.setProfile(p);
            }
        }

        ModeCard {
            cardTitle: "Display"
            currentProfile: root.activeProfile
            currentBrightness: root.currentBrightness
            currentKbd: root.currentKbd
            onProfileChanged: (p) => {
                return root.setProfile(p);
            }
            onBrightnessChanged: (pct) => {
                return root.brightnessChanged(pct);
            }
            onKbdChanged: (pct) => {
                return root.kbdChanged(pct);
            }
        }

        Item {
            Layout.fillHeight: true
        }

    }

}
