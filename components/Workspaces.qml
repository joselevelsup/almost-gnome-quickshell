import Quickshell
import Quickshell.I3
import QtQuick
import ".."

// GNOME 50 workspace indicator: the top-left pill of dots (the active
// workspace is a wider dash). Clicking it opens the overview, like the
// old Activities button. Only the workspaces on this bar's monitor.
BarButton {
    id: root
    active: PopupManager.current === "overview"
    spacing: 5

    readonly property string output: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""

    Repeater {
        model: I3.workspaces.values.filter(w => w.name !== "__i3_scratch"
                && w.monitor && w.monitor.name === root.output)
            .sort((a, b) => (a.number - b.number) || a.name.localeCompare(b.name))
        delegate: Rectangle {
            required property var modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: modelData.active ? 33 : 8
            height: 8
            radius: height / 2
            color: Theme.fg
            opacity: modelData.active ? 1.0 : 0.5

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    onClicked: PopupManager.open("overview")
}
