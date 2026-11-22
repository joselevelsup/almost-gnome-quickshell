import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// GNOME 47-style confirmation for Restart/Power Off from the quick
// settings' power menu: the desktop dims and the action runs by itself
// after 60 seconds unless cancelled. Cancel, Esc or clicking the dimmed
// desktop stops it; the accent button runs it immediately.
PanelWindow {
    id: root
    WlrLayershell.namespace: "quickshell:popup:power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: PopupManager.current === "power"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"

    readonly property bool reboot: PopupManager.powerAction === "reboot"
    property int secondsLeft: 60

    function confirm() {
        // Nothing to run if the popup was opened without openPower()
        // (e.g. a test instance setting PopupManager.current by hand).
        if (!PopupManager.powerAction) return
        PopupManager.close()
        Quickshell.execDetached(["systemctl", PopupManager.powerAction])
    }
    function cancel() { PopupManager.close() }

    // Popups are created already visible (LazyLoader in Bar.qml), hence
    // the onCompleted handler too.
    onVisibleChanged: if (root.visible) keys.forceActiveFocus()
    Component.onCompleted: if (root.visible) keys.forceActiveFocus()
    Timer {
        running: root.visible
        repeat: true
        interval: 1000
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) root.confirm()
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
        }
    }

    // Dimmed desktop; clicking anywhere outside the dialog cancels.
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha("#000000", 0.4)

        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 64
        radius: Theme.radius
        color: Theme.glassBg
        border.width: 1
        border.color: Theme.border

        Column {
            id: col
            anchors { fill: parent; margins: 32 }
            spacing: 20

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.reboot ? "Restart" : "Power Off"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "The system will " + (root.reboot ? "restart" : "power off")
                    + " automatically in " + root.secondsLeft
                    + (root.secondsLeft === 1 ? " second." : " seconds.")
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.features: { "tnum": 1 }
            }
            Row {
                width: parent.width
                spacing: 8
                ChipButton {
                    width: (parent.width - 8) / 2
                    buttonHeight: 52
                    textSize: 16
                    text: "Cancel"
                    onClicked: root.cancel()
                }
                ChipButton {
                    width: (parent.width - 8) / 2
                    buttonHeight: 52
                    textSize: 16
                    text: root.reboot ? "Restart" : "Power Off"
                    selected: true
                    onClicked: root.confirm()
                }
            }
        }
    }
}
