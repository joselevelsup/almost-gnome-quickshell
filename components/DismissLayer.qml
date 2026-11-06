import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Invisible fullscreen layer: closes any open popup when clicking
// outside it, like GNOME Shell.
PanelWindow {
    id: dismiss
    WlrLayershell.namespace: "quickshell:dismiss"
    visible: PopupManager.current !== ""
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.close()
    }
}
