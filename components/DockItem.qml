import Quickshell
import Quickshell.Widgets
import QtQuick
import ".."

// App icon in the Dock: large icon with open-window dots below (up to 3;
// the first one elongated and accented when the app has focus). Only
// emits signals; the logic lives in Dock.qml.
Item {
    id: item
    // { key, entry, appId, windows: [Toplevel], pinned }
    property var app
    // Highlighted while its context menu is open.
    property bool highlighted: false
    readonly property string tipText: app.entry ? app.entry.name : app.appId
    readonly property bool focused: app.windows.some(w => w.activated)
    readonly property bool hovered: mouse.containsMouse

    signal activated
    signal newWindow
    signal menuRequested
    // Pinned items can be dragged sideways to reorder them.
    signal dragMoved
    signal dropped

    property int size: 52
    width: size
    height: size

    property bool dragging: false
    property real dragOffset: 0
    property real pressX: 0
    // Set on a drag's release so the click that follows doesn't launch the app.
    property bool wasDrag: false
    transform: Translate { x: item.dragOffset }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius - 2
        color: mouse.containsMouse || item.highlighted ? Theme.cardHoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    IconImage {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -3
        implicitSize: Math.round(item.size * 0.7)
        source: Quickshell.iconPath(item.app.entry ? item.app.entry.icon : item.app.appId, "application-x-executable")
        scale: mouse.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter }
        spacing: 3
        Repeater {
            model: Math.min(3, item.app.windows.length)
            delegate: Rectangle {
                required property int index
                width: item.focused && index === 0 ? 12 : 4
                height: 4
                radius: 2
                color: item.focused ? Theme.accent : Theme.fg
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true
        onPressed: event => { item.pressX = event.x; item.wasDrag = false }
        onPositionChanged: event => {
            if (!item.app.pinned || !(mouse.pressedButtons & Qt.LeftButton)) return
            // Mouse coords include the drag translation; undo it.
            var dx = event.x + item.dragOffset - item.pressX
            if (!item.dragging && Math.abs(dx) < 8) return
            item.dragging = true
            item.dragOffset = dx
            item.dragMoved()
        }
        onReleased: () => {
            if (!item.dragging) return
            item.dropped()
            item.dragOffset = 0
            item.dragging = false
            item.wasDrag = true
        }
        onCanceled: { item.dragOffset = 0; item.dragging = false }
        onClicked: event => {
            // Release of a drag also emits clicked; swallow it.
            if (item.wasDrag) return
            if (event.button === Qt.RightButton) item.menuRequested()
            else if (event.button === Qt.MiddleButton) item.newWindow()
            else item.activated()
        }
    }
}
