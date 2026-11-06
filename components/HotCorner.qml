import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Hot corner: a tiny surface in a screen corner that fires an action when
// the pointer stays inside for `delay` ms (passing by does nothing, as in
// GNOME). Created from Bar.qml, one per corner; it won't reopen a popup the
// user just closed.
PanelWindow {
    id: hc

    // "top" or "bottom"; always the left corner of the screen.
    property string edge: "top"
    // "overview" opens the workspace mosaic; "apps" the app grid.
    property string action: "overview"

    readonly property int delay: 180

    WlrLayershell.namespace: "quickshell:hotcorner:" + hc.edge
    WlrLayershell.layer: WlrLayer.Overlay
    anchors {
        left: true
        top: hc.edge === "top"
        bottom: hc.edge === "bottom"
    }
    // The bar reserves the top (exclusiveZone), so the compositor pushes
    // this surface down to y=barHeight; the negative margin moves it back
    // to the real screen corner.
    margins { top: hc.edge === "top" ? -Theme.barHeight : 0 }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    implicitWidth: 6
    implicitHeight: 6

    // Fires once per pointer entry: stays false until the pointer leaves
    // the corner.
    property bool armed: true

    Timer {
        id: arm
        interval: hc.delay
        onTriggered: {
            if (!hc.armed) return
            hc.armed = false
            // After closing a popup the pointer is often still in the corner;
            // ignore it briefly so it doesn't reopen right away.
            if (Date.now() - PopupManager.lastChange < 500) return
            if (hc.action === "apps") {
                if (PopupManager.current === "overview" && PopupManager.appsMode) return
                PopupManager.openApps()
            } else {
                // Doesn't toggle: hitting the corner with the overview open
                // doesn't close it.
                if (PopupManager.current === "overview") return
                PopupManager.open("overview")
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (hc.armed) arm.restart()
            } else {
                arm.stop()
                hc.armed = true
            }
        }
    }
}
