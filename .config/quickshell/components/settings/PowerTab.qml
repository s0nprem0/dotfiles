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
    signal screenBrightnessUpdated(int pct)
    signal keyboardBrightnessUpdated(int pct)
    signal chargeLimitUpdated(int limit)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        PowerCard {
            activeProfile: root.activeProfile
            chargeLimit: root.chargeLimit
            onProfileSelected: (p) => {
                return root.setProfile(p);
            }
            onScreenBrightnessUpdated: (pct) => {
                return root.screenBrightnessUpdated(pct);
            }
            onKeyboardBrightnessUpdated: (pct) => {
                return root.keyboardBrightnessUpdated(pct);
            }
            onChargeLimitUpdated: (limit) => {
                return root.chargeLimitUpdated(limit);
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
                return root.screenBrightnessUpdated(pct);
            }
            onKbdChanged: (pct) => {
                return root.keyboardBrightnessUpdated(pct);
            }
        }

        Item {
            Layout.fillHeight: true
        }

    }

}
