import QtQuick
pragma Singleton

Item {
    id: root

    property var popups: ({})
    property string activePopupName: ""
    property var activePopup: null

    signal popupToggled(string name, bool visible)
    signal activePopupChanged(string name)

    function register(name, popupItem) {
        root.popups[name] = popupItem;
    }

    function toggle(name) {
        var popup = root.popups[name];
        if (!popup)
            return;

        if (popup.showPopup) {
            popup.showPopup = false;
            root._clearActive(name);
            return;
        }

        // Close any previously open popup (handles stale references)
        if (root.activePopup && root.activePopup !== popup) {
            if (root.activePopup.showPopup)
                root.activePopup.showPopup = false;
            root._clearActive(root.activePopupName);
        }

        popup.showPopup = true;
        root.activePopupName = name;
        root.activePopup = popup;
        root.popupToggled(name, true);
        root.activePopupChanged(name);
    }

    function closeActive() {
        if (root.activePopup && root.activePopup.showPopup) {
            root.activePopup.showPopup = false;
            root._clearActive(root.activePopupName);
        } else {
            root._clearActive(root.activePopupName);
        }
    }

    function _clearActive(name) {
        root.activePopupName = "";
        root.activePopup = null;
        root.popupToggled(name, false);
        root.activePopupChanged("");
    }
}
