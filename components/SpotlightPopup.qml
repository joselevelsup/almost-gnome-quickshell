import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

// Spotlight-style launcher (after icedman/search-light): a floating search
// box, results below as you type — apps and power actions as a tile grid,
// files as a list (paths don't fit tiles). Plain query searches apps, "/"
// files, ">" power actions. umbriel blurs what's behind the box (layer rule
// for quickshell:popup:spotlight). Up/Down select, Enter runs, Esc clears
// the search or closes, clicking outside closes.
// Opens over IPC: `qs ipc call spotlight toggle`.
PanelWindow {
    id: spotlight
    WlrLayershell.namespace: "quickshell:popup:spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: PopupManager.current === "spotlight"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"

    property string query: ""
    property int selIndex: 0
    readonly property int rowHeight: 58
    readonly property string mode: AppLauncher.modeOf(query)
    readonly property string term: AppLauncher.termOf(query)
    readonly property var results: query.trim().length > 0 ? AppLauncher.tiles(query) : []
    onQueryChanged: {
        selIndex = 0
        if (mode === "files") FileSearch.search(term)
        list.positionViewAtBeginning()
        grid.positionViewAtBeginning()
    }

    // Close before run: runAction may open the power dialog, which sets
    // PopupManager.current, so a close after would cancel it instantly.
    function activate(tile) {
        if (!tile) return
        PopupManager.close()
        tile.run()
    }
    function moveSelection(delta) {
        if (results.length === 0) return
        selIndex = Math.max(0, Math.min(results.length - 1, selIndex + delta))
        if (mode === "files") list.positionViewAtIndex(selIndex, ListView.Contain)
        else grid.positionViewAtIndex(selIndex, GridView.Contain)
    }

    onVisibleChanged: {
        if (visible) {
            box.opacity = 0
            box.scale = 0.97
            openAnim.restart()
            searchInput.forceActiveFocus()
        } else {
            query = ""
        }
    }

    MouseArea { anchors.fill: parent; onClicked: PopupManager.close() }

    Rectangle {
        id: box
        width: Math.min(768, parent.width - 48)
        height: field.height + body.height
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.round(parent.height * 0.22) }
        radius: Theme.radius
        color: Theme.glassBg
        border.width: 1
        border.color: Theme.border
        clip: true

        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: box; property: "opacity"; to: 1; duration: 140 }
            NumberAnimation { target: box; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        // Clicks inside the box must not close it.
        MouseArea { anchors.fill: parent; onClicked: searchInput.forceActiveFocus() }

        // ---- Search field ----
        Item {
            id: field
            width: parent.width
            height: 67

            SymbolicIcon {
                id: searchIcon
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                name: "system-search-symbolic"
                size: 22
                tint: Theme.fgDim
            }

            TextInput {
                id: searchInput
                anchors { left: searchIcon.right; right: clearBtn.left; leftMargin: 12; rightMargin: 6; verticalCenter: parent.verticalCenter }
                text: spotlight.query
                onTextEdited: spotlight.query = text
                color: Theme.fg
                selectionColor: Theme.activeBg
                selectedTextColor: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 18
                clip: true
                focus: true

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (spotlight.query.length > 0) spotlight.query = ""
                        else PopupManager.close()
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        spotlight.activate(spotlight.results[spotlight.selIndex])
                        break
                    // In the grid Up/Down jump a row, in the file list a line.
                    case Qt.Key_Up:   spotlight.moveSelection(spotlight.mode === "files" ? -1 : -4); break
                    case Qt.Key_Down: spotlight.moveSelection(spotlight.mode === "files" ? 1 : 4); break
                    case Qt.Key_Left:
                    case Qt.Key_Right:
                        // While typing a path the horizontal arrows edit the text.
                        if (spotlight.mode === "files") return
                        spotlight.moveSelection(event.key === Qt.Key_Left ? -1 : 1)
                        break
                    case Qt.Key_Tab:     spotlight.moveSelection(1); break
                    case Qt.Key_Backtab: spotlight.moveSelection(-1); break
                    default: return
                    }
                    event.accepted = true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: spotlight.mode === "files" ? "Search files"
                        : spotlight.mode === "power" ? "Power actions" : "Search apps"
                    color: Theme.fgDim
                    font: searchInput.font
                }
            }

            IconButton {
                id: clearBtn
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                implicitWidth: 34
                implicitHeight: 34
                flat: true
                icon: "edit-clear-symbolic"
                tint: Theme.fgDim
                visible: spotlight.query.length > 0
                onClicked: { spotlight.query = ""; searchInput.forceActiveFocus() }
            }
        }

        // ---- Results ----
        Item {
            id: body
            anchors.top: field.bottom
            width: parent.width
            // Nothing below the field until there's a query; at most 8 file
            // rows or 3 grid rows show, the rest scrolls.
            height: spotlight.query.trim().length === 0 ? 0
                  : spotlight.results.length === 0 ? 77
                  : spotlight.mode === "files"
                    ? Math.min(spotlight.results.length, 8) * spotlight.rowHeight + 16
                    : Math.min(Math.ceil(spotlight.results.length / 4), 3) * 116 + 16

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
                visible: parent.height > 0
            }

            // File paths don't fit tiles: rows with the parent directory.
            ListView {
                id: list
                anchors { fill: parent; margins: 8 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: spotlight.mode === "files"
                model: spotlight.results

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === spotlight.selIndex
                    width: ListView.view.width
                    height: spotlight.rowHeight
                    radius: Theme.radius - 6
                    color: selected ? Theme.activeBg : "transparent"
                    border.width: selected ? 2 : 0
                    border.color: Theme.accent
                    scale: rowMouse.pressed ? 0.97 : 1

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    IconImage {
                        id: rowIcon
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        implicitSize: 38
                    }

                    Column {
                        anchors { left: rowIcon.right; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            width: parent.width
                            text: row.modelData.name
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.sub
                            visible: text.length > 0
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: spotlight.selIndex = row.index
                        onClicked: spotlight.activate(row.modelData)
                    }
                }
            }

            // Apps and power actions as a compact tile grid.
            GridView {
                id: grid
                anchors { fill: parent; margins: 8 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: spotlight.mode !== "files"
                model: spotlight.results
                cellWidth: (box.width - 16) / 4
                cellHeight: 116

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: tile
                        anchors { fill: parent; margins: 3 }
                        readonly property bool selected: cell.index === spotlight.selIndex
                        radius: Theme.radius - 2
                        color: selected ? Theme.activeBg : tileMouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                        border.width: selected ? 2 : 1
                        border.color: selected ? Theme.accent : Theme.border
                        scale: tileMouse.pressed ? 0.96 : 1

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: 6
                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                                implicitSize: 56
                            }
                            Text {
                                width: parent.width - 4
                                text: cell.modelData.name
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: tile.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: spotlight.selIndex = cell.index
                            onClicked: spotlight.activate(cell.modelData)
                        }
                    }
                }
            }

            // Empty state.
            Row {
                anchors.centerIn: parent
                visible: spotlight.query.trim().length > 0 && spotlight.results.length === 0
                spacing: 10
                SymbolicIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "system-search-symbolic"
                    tint: Theme.fgDim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: spotlight.mode === "files" && spotlight.term.length === 0 ? "Type a file name"
                        : "No results for “" + spotlight.query.trim() + "”"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }
        }
    }
}
