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

    implicitWidth: 330
    // Fixed height (see PopupCard): no surface resize while banners come and go.
    implicitHeight: toasts.screen ? toasts.screen.height - Theme.barHeight : 700
    mask: Region { item: column }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: toasts.toastTopMargin
        spacing: 8
        width: 330

        // The others glide into place when a banner arrives or leaves.
        move: Transition {
            NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            // The live model, not .values: a fresh array would recreate every
            // banner and replay their entrance.
            model: Notifications.server.trackedNotifications
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

                // Entrance: fade in while dropping from above, with one soft
                // overshoot. Exit: fade out while lifting, then dismiss.
                property bool leaving: false
                function leave() {
                    if (toast.leaving) return
                    toast.leaving = true
                    enterAnim.stop()
                    exitAnim.start()
                }

                opacity: 0
                transform: Translate { id: shift; y: -40 }
                Component.onCompleted: enterAnim.start()

                ParallelAnimation {
                    id: enterAnim
                    NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: shift; property: "y"; to: 0; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
                SequentialAnimation {
                    id: exitAnim
                    ParallelAnimation {
                        NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation { target: shift; property: "y"; to: -20; duration: 200; easing.type: Easing.InCubic }
                    }
                    ScriptAction {
                        script: if (toast.modelData && toast.modelData.dismiss) toast.modelData.dismiss()
                    }
                }

                onDismissRequested: toast.leave()

                // Auto-dismiss pauses while hovered, so the notification
                // can be read calmly.
                HoverHandler { id: toastHover }

                Timer {
                    interval: 6000
                    running: !toastHover.hovered && !toast.leaving
                    onTriggered: toast.leave()
                }
            }
        }
    }
}
