import Quickshell
import QtQuick
import ".."

// GNOME 50 workspace indicator: the top-left pill of dots (the active
// workspace is a wider dash). Clicking it opens umbriel's overview, like the
// old Activities button. Only the workspaces on this bar's monitor.
BarButton {
    id: root
    spacing: 5

    readonly property string output: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""

    readonly property var list: Umbriel.workspaces.filter(w => w.output === root.output)
        .sort((a, b) => a.index - b.index)

    // A count model keeps the pills alive across updates (every umbriel event
    // brings new objects), so their width can animate.
    Repeater {
        model: root.list.length
        delegate: Rectangle {
            required property int index
            readonly property bool isActive: root.list[index] ? root.list[index].active : false
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: isActive ? 33 : 8
            height: 8
            radius: height / 2
            color: Theme.fg
            opacity: isActive ? 1.0 : 0.5

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    onClicked: Umbriel.msg(["overview-toggle"])
}
