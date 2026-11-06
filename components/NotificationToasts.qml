import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Pop-up notification banners, centered below the bar like in GNOME.
PanelWindow {
    id: toasts
    WlrLayershell.namespace: "quickshell:toast"
    WlrLayershell.layer: WlrLayer.Overlay
    visible: Notifications.server.trackedNotifications.values.length > 0
    anchors { top: true }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    // Gap below the bar. Note: it is part of the surface's total height, so
    // it must be added to implicitHeight or the card (placed with this
    // margin) gets clipped at the bottom edge.
    readonly property int toastTopMargin: 40

    implicitWidth: 300
    implicitHeight: column.implicitHeight + toastTopMargin

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: toasts.toastTopMargin
        spacing: 8
        width: 300

        Repeater {
            model: Notifications.server.trackedNotifications.values
            delegate: NotificationRow {
                id: toast
                required property var modelData
                width: column.width
                appName: modelData.appName
                summary: modelData.summary
                body: modelData.body || ""
                appIcon: modelData.appIcon || ""
                time: null
                elevated: true
                onDismissRequested: {
                    if (toast.modelData && toast.modelData.dismiss) toast.modelData.dismiss()
                }

                // Auto-dismiss pauses while hovered, so the notification
                // can be read calmly.
                HoverHandler { id: toastHover }

                Timer {
                    interval: 6000
                    running: !toastHover.hovered
                    onTriggered: {
                        if (toast.modelData && toast.modelData.dismiss) toast.modelData.dismiss()
                    }
                }
            }
        }
    }
}
