import Quickshell
import QtQuick
import ".."

// Context menu for a dock icon (right-click): the app's open windows, new
// window, pin/unpin and close. An xdg popup anchored above the icon; a
// click outside closes it (grabFocus).
PopupWindow {
    id: menu
    property var dockWindow
    // Store the key, not the object: Dock.apps is rebuilt whenever windows
    // change, and the menu must always see live state.
    property string appKey: ""
    readonly property var app: dockWindow && appKey ? (dockWindow.apps.find(a => a.key === appKey) || null) : null
    property Item anchorItem: null

    function openFor(app, item) {
        menu.appKey = app.key
        menu.anchorItem = item
        menu.visible = true
    }
    function closeMenu() { menu.visible = false }
    // If the app disappears (its last window closed and it isn't pinned).
    onAppChanged: if (visible && !app) closeMenu()

    anchor.window: dockWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -10
    visible: false
    color: "transparent"
    implicitWidth: 264
    implicitHeight: col.implicitHeight + 12

    grabFocus: true

    onVisibleChanged: if (visible) { card.opacity = 0; openAnim.restart() }
    NumberAnimation { id: openAnim; target: card; property: "opacity"; to: 1; duration: 140 }

    readonly property var windows: app ? app.windows : []
    readonly property var entry: app ? app.entry : null

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
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
                font.pixelSize: 15
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // Open windows (only with more than one, to choose from).
            Repeater {
                model: menu.windows.length > 1 ? menu.windows : []
                delegate: ActionRow {
                    required property var modelData
                    width: col.width
                    icon: "focus-windows-symbolic"
                    label: modelData.title || "Untitled"
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
                label: "New Window"
                onClicked: { AppLauncher.launch(menu.entry); menu.closeMenu() }
            }
            ActionRow {
                width: col.width
                visible: menu.entry !== null
                icon: menu.app && menu.app.pinned ? "list-remove-symbolic" : "view-pin-symbolic"
                label: menu.app && menu.app.pinned ? "Unpin" : "Pin to Dash"
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
                label: menu.windows.length > 1 ? "Quit " + menu.windows.length + " Windows" : "Quit"
                tint: Theme.danger
                onClicked: {
                    menu.windows.slice().forEach(w => w.close())
                    menu.closeMenu()
                }
            }
        }
    }
}
