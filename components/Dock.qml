import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import ".."

// Dock inferior al estilo dash-to-dock de GNOME: apps fijadas (DockPins),
// luego las abiertas sin fijar, y el botón de "Mostrar aplicaciones" que
// abre el overview. Las ventanas salen de wlr-foreign-toplevel
// (ToplevelManager), así que el estado es en vivo y sin sondeo.
//
// Se oculta solo para no robar alto en 1366×768: aparece al llevar el
// puntero al borde inferior, y queda fijo mientras el workspace actual
// esté vacío o haya un menú abierto.
//
// Click: abre la app, la enfoca o, con varias ventanas, rota entre ellas.
// Click medio: ventana nueva. Click derecho: menú.
PanelWindow {
    id: dock
    WlrLayershell.namespace: "quickshell:popup:dock"
    WlrLayershell.layer: WlrLayer.Top
    anchors { bottom: true; left: true; right: true }
    exclusiveZone: 0
    focusable: false
    color: "transparent"
    implicitHeight: 120

    // Solo el cuerpo (o la franja de activación, si está oculto) recibe el
    // puntero; el resto de la superficie deja pasar los clicks.
    mask: Region { item: dock.revealed ? body : trigger }

    // ---- Modelo ----
    function entryFor(appId) {
        return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)
    }
    readonly property var apps: {
        DesktopEntries.applications.values // re-evaluar cuando cambian los .desktop
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
        // Con varias ventanas, cada click pasa a la siguiente.
        var i = app.windows.findIndex(w => w.activated)
        app.windows[(i + 1) % app.windows.length].activate()
    }

    // ---- Visibilidad ----
    readonly property bool workspaceEmpty: Hyprland.focusedWorkspace !== null
        && Hyprland.focusedWorkspace.toplevels.values.length === 0
    property bool hot: false
    readonly property bool revealed: hot || workspaceEmpty || menu.visible

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: dock.hot = false
    }

    // Franja invisible pegada al borde inferior que despierta el dock.
    Item {
        id: trigger
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: body.width
        height: 3
        HoverHandler {
            onHoveredChanged: if (hovered) { hideTimer.stop(); dock.hot = true }
        }
    }

    // ---- Cuerpo ----
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.revealed ? dock.height - height - 8 : dock.height + 4
        width: row.implicitWidth + 12
        height: 64
        radius: Theme.radius + 4
        color: Theme.popupBg
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

                    // Separador entre fijadas y abiertas sin fijar.
                    Rectangle {
                        visible: !slot.modelData.pinned && slot.index > 0 && dock.apps[slot.index - 1].pinned
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 36
                        color: Theme.border
                    }

                    DockItem {
                        id: dockItem
                        app: slot.modelData
                        highlighted: menu.visible && menu.appKey === slot.modelData.key
                        onHoveredChanged: tooltip.target = hovered ? dockItem : (tooltip.target === dockItem ? null : tooltip.target)
                        onActivated: dock.activateApp(slot.modelData)
                        onNewWindow: if (slot.modelData.entry) AppLauncher.launch(slot.modelData.entry)
                        onMenuRequested: menu.openFor(slot.modelData, dockItem)
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 36
                color: Theme.border
            }

            // "Mostrar aplicaciones": abre el overview (con su buscador).
            Rectangle {
                id: gridBtn
                readonly property string tipText: "Mostrar aplicaciones"
                width: 52
                height: 52
                radius: Theme.radius - 2
                color: gridMouse.containsMouse ? Theme.cardHoverBg : "transparent"
                scale: gridMouse.pressed ? 0.94 : 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                SymbolicIcon {
                    anchors.centerIn: parent
                    name: "view-app-grid-symbolic"
                    size: 24
                }
                MouseArea {
                    id: gridMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: tooltip.target = containsMouse ? gridBtn : (tooltip.target === gridBtn ? null : tooltip.target)
                    onClicked: PopupManager.open("overview")
                }
            }
        }
    }

    // ---- Tooltip con el nombre ----
    Rectangle {
        id: tooltip
        property Item target: null
        readonly property bool active: target !== null && dock.revealed && !menu.visible
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.toastBg
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

    // ---- Menú contextual ----
    DockMenu {
        id: menu
        dockWindow: dock
    }
}
