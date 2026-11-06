import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Base for the bar's floating popups (calendar, quick settings):
// rounded, translucent card anchored below the bar.
PanelWindow {
    id: popup
    property string popupName: ""
    // "left" (below the workspace indicator), "right" (below the status pill) or "center" (below the clock)
    property string align: "right"
    property int cardWidth: 300
    default property alias content: column.data

    WlrLayershell.namespace: "quickshell:popup:" + popup.popupName
    // Above the dismiss layer: otherwise both surfaces sit on the same
    // layer and clicks can go to the one below instead of reaching the
    // popup's controls.
    WlrLayershell.layer: WlrLayer.Overlay
    visible: PopupManager.current === popup.popupName
    color: "transparent"
    anchors {
        top: true
        left: popup.align === "left"
        right: popup.align === "right"
    }
    margins {
        top: 6
        left: popup.align === "left" ? 8 : 0
        right: popup.align === "right" ? 8 : 0
    }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false

    implicitWidth: popup.cardWidth
    implicitHeight: column.implicitHeight + 24

    // Smooth entrance (fade + slight slide) every time it opens.
    onVisibleChanged: if (popup.visible) openAnim.restart()
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; from: -6; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: Theme.radius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.border

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
        }
    }
}
