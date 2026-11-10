import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

// Bottom dock in the style of GNOME's dash-to-dock: pinned apps (DockPins),
// then running apps that aren't pinned, and a "Show Apps" button that opens
// the app grid. Windows come from wlr-foreign-toplevel (ToplevelManager),
// so state is live without polling.
//
// Auto-hides (Settings) to save height on 1366×768: it appears when the
// pointer reaches the bottom edge, and stays while the current workspace is
// empty or a menu is open. With auto-hide off it reserves its space.
//
// Click: launch the app, focus it or, with several windows, cycle them.
// Middle-click: new window. Right-click: menu.
PanelWindow {
    id: dock
    WlrLayershell.namespace: "quickshell:popup:dock"
    WlrLayershell.layer: WlrLayer.Top
    anchors { bottom: true; left: true; right: true }
    exclusiveZone: Settings.options.dockAutohide ? 0 : body.height + 8
    focusable: false
    color: "transparent"
    implicitHeight: 120

    // Only the body (or the trigger strip, when hidden) takes the pointer;
    // the rest of the surface lets clicks through.
    mask: Region { item: dock.revealed ? body : trigger }

    // ---- Model ----
    function entryFor(appId) {
        return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)
    }
    readonly property var apps: {
        DesktopEntries.applications.values // re-evaluate when .desktop files change
        var list = []
        var byKey = {}
        for (var i = 0; i < DockPins.pinned.length; i++) {
            var pe = DesktopEntries.byId(DockPins.pinned[i])
            if (!pe || byKey[pe.id]) continue
            byKey[pe.id] = { key: pe.id, entry: pe, windows: [], pinned: true }
            list.push(byKey[pe.id])
        }
        var tops = ToplevelManager.toplevels.values
        for (var j = 0; j < tops.length; j++) {
            var t = tops[j]
            var e = entryFor(t.appId)
            var key = e ? e.id : t.appId
            if (!byKey[key]) {
                byKey[key] = { key: key, entry: e, appId: t.appId, windows: [], pinned: false }
                list.push(byKey[key])
            }
            byKey[key].windows.push(t)
        }
        return list
    }

    function activateApp(app) {
        if (app.windows.length === 0) {
            if (app.entry) AppLauncher.launch(app.entry)
            return
        }
        // With several windows, each click moves to the next one.
        var i = app.windows.findIndex(w => w.activated)
        app.windows[(i + 1) % app.windows.length].activate()
    }

    // ---- Drag to reorder pinned apps ----
    // Pinned apps come first in `apps`, so their slot index is their order.
    readonly property int pinnedCount: apps.filter(a => a.pinned).length
    property int dragFrom: -1
    property int dropIndex: -1
    function dragTo(index, item) {
        var cx = item.mapToItem(row, item.width / 2, 0).x
        dock.dragFrom = index
        dock.dropIndex = Math.max(0, Math.min(dock.pinnedCount - 1, Math.round((cx - dock.tile / 2) / (dock.tile + 4))))
    }
    function drop() {
        if (dock.dropIndex < 0 || dock.dropIndex === dock.dragFrom) return
        var id = dock.apps[dock.dragFrom].key, target = dock.apps[dock.dropIndex].key
        // Deferred: the move rebuilds the delegate that is emitting this.
        Qt.callLater(() => DockPins.move(id, target))
    }

    // ---- Visibility ----
    readonly property bool workspaceEmpty: Umbriel.focusedWorkspace !== null && !Umbriel.focusedWorkspace.occupied
    property bool hot: false
    readonly property bool revealed: !Settings.options.dockAutohide || hot || workspaceEmpty || menu.visible || dragFrom !== -1
    // Icon tile size from Settings.
    readonly property int tile: ({ small: 44, large: 64 })[Settings.options.dockIconSize] || 52

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: dock.hot = false
    }

    // Invisible strip along the bottom edge that wakes the dock.
    Item {
        id: trigger
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: body.width
        height: 3
        HoverHandler {
            onHoveredChanged: if (hovered) { hideTimer.stop(); dock.hot = true }
        }
    }

    // ---- Body ----
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.revealed ? dock.height - height - 8 : dock.height + 4
        width: row.implicitWidth + 12
        height: dock.tile + 12
        radius: Theme.radius + 4
        color: Theme.glassBg
        border.width: 1
        border.color: Theme.border

        opacity: dock.revealed ? 1 : 0

        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: bodyHover
            onHoveredChanged: {
                if (hovered) { hideTimer.stop(); dock.hot = true }
                else hideTimer.restart()
            }
        }

        // Drop position while dragging a pinned app: in the gap before the
        // target slot (moving left) or after it (moving right).
        Rectangle {
            visible: dock.dropIndex !== -1 && dock.dropIndex !== dock.dragFrom
            x: row.x + (dock.dropIndex > dock.dragFrom ? dock.dropIndex + 1 : dock.dropIndex) * (dock.tile + 4) - 3
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: dock.tile - 8
            radius: 1
            color: Theme.accent
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: dock.apps
                delegate: Row {
                    id: slot
                    required property var modelData
                    required property int index
                    spacing: 4
                    z: dockItem.dragging ? 1 : 0
                    Component.onDestruction: if (dockItem.dragging) dock.dragFrom = dock.dropIndex = -1

                    // Separator between pinned and unpinned running apps.
                    Rectangle {
                        visible: !slot.modelData.pinned && slot.index > 0 && dock.apps[slot.index - 1].pinned
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: dock.tile - 16
                        color: Theme.border
                    }

                    DockItem {
                        id: dockItem
                        app: slot.modelData
                        size: dock.tile
                        highlighted: menu.visible && menu.appKey === slot.modelData.key
                        onHoveredChanged: tooltip.target = hovered ? dockItem : (tooltip.target === dockItem ? null : tooltip.target)
                        onActivated: dock.activateApp(slot.modelData)
                        onNewWindow: if (slot.modelData.entry) AppLauncher.launch(slot.modelData.entry)
                        onMenuRequested: menu.openFor(slot.modelData, dockItem)
                        onDragMoved: dock.dragTo(slot.index, dockItem)
                        onDropped: dock.drop()
                        onDraggingChanged: if (!dragging) dock.dragFrom = dock.dropIndex = -1
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: dock.tile - 16
                color: Theme.border
            }

            // "Show Apps": opens the app grid, like GNOME's dash.
            Rectangle {
                id: gridBtn
                readonly property string tipText: "Show Apps"
                width: dock.tile
                height: dock.tile
                radius: Theme.radius - 2
                color: gridMouse.containsMouse ? Theme.cardHoverBg : "transparent"
                scale: gridMouse.pressed ? 0.94 : 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                SymbolicIcon {
                    anchors.centerIn: parent
                    name: "view-app-grid-symbolic"
                    size: Math.round(dock.tile * 0.46)
                }
                MouseArea {
                    id: gridMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: tooltip.target = containsMouse ? gridBtn : (tooltip.target === gridBtn ? null : tooltip.target)
                    onClicked: PopupManager.open("launcher")
                }
            }
        }
    }

    // ---- Name tooltip ----
    Rectangle {
        id: tooltip
        property Item target: null
        readonly property bool active: target !== null && dock.revealed && !menu.visible && dock.dragFrom === -1
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.glassBg
        border.width: 1
        border.color: Theme.border
        y: body.y - height - 8
        x: {
            if (!target) return x
            var p = target.mapToItem(dock.contentItem, target.width / 2, 0)
            return Math.max(8, Math.min(dock.width - width - 8, p.x - width / 2))
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: tooltip.target ? tooltip.target.tipText : ""
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    // ---- Context menu ----
    DockMenu {
        id: menu
        dockWindow: dock
    }
}
