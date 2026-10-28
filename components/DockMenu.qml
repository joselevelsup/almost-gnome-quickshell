import Quickshell
import Quickshell.Hyprland
import QtQuick
import ".."

// Menú contextual de un icono del Dock (click derecho): ventanas abiertas
// de la app, ventana nueva, fijar/quitar del dock y cerrar. Es un popup
// xdg anclado sobre el icono; un click fuera lo cierra (HyprlandFocusGrab).
PopupWindow {
    id: menu
    property var dockWindow
    // Se guarda la clave y no el objeto: Dock.apps se recalcula cada vez que
    // cambian las ventanas, y el menú debe ver siempre el estado en vivo.
    property string appKey: ""
    readonly property var app: dockWindow && appKey ? (dockWindow.apps.find(a => a.key === appKey) || null) : null
    property Item anchorItem: null

    function openFor(app, item) {
        menu.appKey = app.key
        menu.anchorItem = item
        menu.visible = true
    }
    function closeMenu() { menu.visible = false }
    // Si la app desaparece (se cerró su última ventana y no está fijada).
    onAppChanged: if (visible && !app) closeMenu()

    anchor.window: dockWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -10
    visible: false
    color: "transparent"
    implicitWidth: 240
    implicitHeight: col.implicitHeight + 12

    HyprlandFocusGrab {
        windows: [menu]
        active: menu.visible
        onCleared: menu.closeMenu()
    }

    onVisibleChanged: if (visible) { card.opacity = 0; openAnim.restart() }
    NumberAnimation { id: openAnim; target: card; property: "opacity"; to: 1; duration: 140 }

    readonly property var windows: app ? app.windows : []
    readonly property var entry: app ? app.entry : null

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
        // Popup xdg: Hyprland no le aplica blur de capa, por eso el fondo casi opaco.
        color: Theme.toastBg
        border.width: 1
        border.color: Theme.border

        Column {
            id: col
            anchors { fill: parent; margins: 6 }
            spacing: 0

            Text {
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 6
                text: menu.entry ? menu.entry.name : (menu.app ? menu.app.appId : "")
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // Ventanas abiertas (solo con más de una, para elegir).
            Repeater {
                model: menu.windows.length > 1 ? menu.windows : []
                delegate: ActionRow {
                    required property var modelData
                    width: col.width
                    icon: "focus-windows-symbolic"
                    label: modelData.title || "Sin título"
                    tint: modelData.activated ? Theme.accent : Theme.fg
                    onClicked: { modelData.activate(); menu.closeMenu() }
                }
            }
            Rectangle {
                visible: menu.windows.length > 1
                width: parent.width
                height: 9
                color: "transparent"
                Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.border }
            }

            ActionRow {
                width: col.width
                visible: menu.entry !== null
                icon: "window-new-symbolic"
                label: "Nueva ventana"
                onClicked: { AppLauncher.launch(menu.entry); menu.closeMenu() }
            }
            ActionRow {
                width: col.width
                visible: menu.entry !== null
                icon: menu.app && menu.app.pinned ? "list-remove-symbolic" : "view-pin-symbolic"
                label: menu.app && menu.app.pinned ? "Quitar del dock" : "Fijar en el dock"
                onClicked: {
                    if (menu.app.pinned) DockPins.unpin(menu.entry.id)
                    else DockPins.pin(menu.entry.id)
                    menu.closeMenu()
                }
            }
            ActionRow {
                width: col.width
                visible: menu.windows.length > 0
                icon: "window-close-symbolic"
                label: menu.windows.length > 1 ? "Cerrar " + menu.windows.length + " ventanas" : "Cerrar"
                tint: Theme.danger
                onClicked: {
                    menu.windows.slice().forEach(w => w.close())
                    menu.closeMenu()
                }
            }
        }
    }
}
