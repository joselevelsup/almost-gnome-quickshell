import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."

// GNOME-style app grid over the blurred wallpaper: every app in pages, and
// typing searches them (Enter launches the selected one). Esc clears the
// search or closes. The workspace overview is umbriel's own.
// Opens from the dock, the bottom-left hot corner or over IPC:
// `qs ipc call launcher toggle`.
PanelWindow {
    id: launcher
    WlrLayershell.namespace: "quickshell:popup:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive keyboard only while open, for Esc and search.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: PopupManager.current === "launcher"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"

    // ---- App search ----
    // With an empty query every app is listed; typing narrows it down.
    property string query: ""
    property int selIndex: 0
    readonly property int resultCols: 6
    readonly property int tileGap: 12
    // As many rows of 150px tiles as fit (available height: below the search
    // bar, above the page dots).
    readonly property int perPage: resultCols * Math.max(1, Math.floor((height - 96 - 16 - 56 + tileGap) / (150 + tileGap)))
    readonly property var results: {
        var q = query.trim().toLowerCase()
        var apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        if (q.length === 0) return apps.slice().sort((a, b) => a.name.localeCompare(b.name))
        function score(e) {
            var n = (e.name || "").toLowerCase()
            if (n.startsWith(q)) return 100
            if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
            if (n.indexOf(q) !== -1) return 60
            var extra = [e.genericName || "", (e.keywords || []).join(" "), e.id || ""].join(" ").toLowerCase()
            if (extra.indexOf(q) !== -1) return 40
            if ((e.comment || "").toLowerCase().indexOf(q) !== -1) return 20
            return 0
        }
        return apps
            .map(e => ({ entry: e, score: score(e) }))
            .filter(r => r.score > 0)
            .sort((a, b) => (b.score - a.score) || a.entry.name.localeCompare(b.entry.name))
            .slice(0, 18)
            .map(r => r.entry)
    }
    onQueryChanged: { selIndex = 0; pages.currentIndex = 0 }

    function launch(entry) {
        if (!entry) return
        AppLauncher.launch(entry)
        PopupManager.close()
    }
    function moveSelection(delta) {
        if (results.length === 0) return
        selIndex = Math.max(0, Math.min(results.length - 1, selIndex + delta))
        pages.currentIndex = Math.floor(selIndex / perPage)
    }

    onVisibleChanged: {
        if (visible) {
            content.opacity = 0
            content.scale = 0.97
            pages.currentIndex = 0
            openAnim.restart()
            searchInput.forceActiveFocus()
        } else {
            query = ""
        }
    }

    Item {
        id: backdrop
        anchors.fill: parent

        // ---- Background: blurred, dimmed wallpaper, like GNOME ----
        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha("#000000", 1)
        }
        Image {
            id: bgImage
            anchors.fill: parent
            source: Wallpaper.current ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 683
            sourceSize.height: 384
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgImage
            visible: bgImage.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: 48
        }
        // Dark tint so fg/fgDim stay readable over any wallpaper.
        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha("#000000", 0.55)
        }

        MouseArea { anchors.fill: parent; onClicked: PopupManager.close() }

        Item {
            id: content
            anchors.fill: parent
            transformOrigin: Item.Center

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: 140 }
                NumberAnimation { target: content; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }

            // ---- Header: search field ----
            Column {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 20 }
                spacing: 6

                Rectangle {
                    width: 380
                    height: 36
                    radius: height / 2
                    color: Theme.popupBg
                    border.width: 2
                    border.color: Theme.accent

                    // Clicking the field must not close the launcher.
                    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: searchInput.forceActiveFocus() }

                    SymbolicIcon {
                        id: searchIcon
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        name: "system-search-symbolic"
                        tint: Theme.fgDim
                    }

                    TextInput {
                        id: searchInput
                        anchors { left: searchIcon.right; right: clearBtn.left; leftMargin: 10; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: launcher.query
                        onTextEdited: launcher.query = text
                        color: Theme.fg
                        selectionColor: Theme.activeBg
                        selectedTextColor: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        clip: true
                        focus: true

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                // Clear the search first; with an empty field
                                // (or in the grid), close.
                                if (launcher.query.trim().length > 0) launcher.query = ""
                                else PopupManager.close()
                                break
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                launcher.launch(launcher.results[launcher.selIndex])
                                break
                            case Qt.Key_Left:  launcher.moveSelection(-1); break
                            case Qt.Key_Right: launcher.moveSelection(1); break
                            case Qt.Key_Up:    launcher.moveSelection(-launcher.resultCols); break
                            case Qt.Key_Down:  launcher.moveSelection(launcher.resultCols); break
                            case Qt.Key_Tab:   launcher.moveSelection(1); break
                            default: return
                            }
                            event.accepted = true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Type to search"
                            color: Theme.fgDim
                            font: searchInput.font
                        }
                    }

                    IconButton {
                        id: clearBtn
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        implicitWidth: 28
                        implicitHeight: 28
                        flat: true
                        icon: "edit-clear-symbolic"
                        tint: Theme.fgDim
                        visible: launcher.query.length > 0
                        onClicked: { launcher.query = ""; searchInput.forceActiveFocus() }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Enter to open · arrows to select · Esc to close"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // ---- Apps ----
            Item {
                anchors.fill: parent
                anchors.topMargin: 96

                // Pages of apps, like GNOME: swipe, scroll or use the dots.
                ListView {
                    id: pages
                    anchors.fill: parent
                    anchors.topMargin: 16
                    anchors.bottomMargin: 56
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 250
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    model: Math.ceil(launcher.results.length / launcher.perPage)
                    // Keyboard selection drags the page along; a swipe moves
                    // the selection onto the new page.
                    onCurrentIndexChanged: if (Math.floor(launcher.selIndex / launcher.perPage) !== currentIndex)
                        launcher.selIndex = currentIndex * launcher.perPage

                    // Pages only move by whole pages: the list's own wheel/drag
                    // scrolling would pan pixel by pixel.
                    interactive: false


                    delegate: Item {
                        id: page
                        required property int index
                        width: pages.width
                        height: pages.height

                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: Math.min(launcher.resultCols, Math.max(1, launcher.results.length))
                            spacing: launcher.tileGap

                            Repeater {
                                model: launcher.results.slice(page.index * launcher.perPage, (page.index + 1) * launcher.perPage)
                                delegate: Rectangle {
                                    id: appTile
                                    required property var modelData
                                    required property int index
                                    readonly property int gi: page.index * launcher.perPage + index
                                    readonly property bool selected: gi === launcher.selIndex
                                    width: 160
                                    height: 150
                                    radius: Theme.radius - 2
                                    color: selected ? Theme.activeBg : appMouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg
                                    border.width: selected ? 2 : 1
                                    border.color: selected ? Theme.accent : Theme.border
                                    scale: appMouse.pressed ? 0.96 : 1

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        spacing: 10
                                        IconImage {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            source: Quickshell.iconPath(appTile.modelData.icon, "application-x-executable")
                                            implicitSize: 72
                                        }
                                        Text {
                                            width: parent.width
                                            text: appTile.modelData.name
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: appTile.selected ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        // Tiles sliding under the pointer mid-swipe must not select.
                                    onEntered: if (page.index === pages.currentIndex) launcher.selIndex = appTile.gi
                                        onClicked: launcher.launch(appTile.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // A short two-finger swipe (or one wheel notch), either
                // direction, flips one page; the rest of that gesture is
                // ignored. Takes no buttons, so tiles still get clicks and hover.
                MouseArea {
                    id: swipeArea
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    property real acc: 0
                    property bool done: false
                    onWheel: wheel => {
                        swipeEnd.restart()
                        if (done) return
                        acc += wheel.angleDelta.x || wheel.angleDelta.y || wheel.pixelDelta.x || wheel.pixelDelta.y
                        if (Math.abs(acc) < 60) return
                        pages.currentIndex = Math.max(0, Math.min(pages.count - 1, pages.currentIndex + (acc < 0 ? 1 : -1)))
                        done = true
                    }
                    // The gesture is over once events stop.
                    Timer { id: swipeEnd; interval: 250; onTriggered: { swipeArea.acc = 0; swipeArea.done = false } }
                }

                // Page dots.
                Row {
                    anchors { bottom: parent.bottom; bottomMargin: 24; horizontalCenter: parent.horizontalCenter }
                    spacing: 10
                    visible: pages.count > 1
                    Repeater {
                        model: pages.count
                        delegate: Rectangle {
                            required property int index
                            width: index === pages.currentIndex ? 24 : 10
                            height: 10
                            radius: 5
                            color: Theme.fg
                            opacity: index === pages.currentIndex ? 1.0 : 0.4
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pages.currentIndex = parent.index
                            }
                        }
                    }
                }

                // Empty state.
                Column {
                    anchors { top: parent.top; topMargin: 80; horizontalCenter: parent.horizontalCenter }
                    visible: launcher.results.length === 0
                    spacing: 8
                    SymbolicIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "system-search-symbolic"
                        size: 32
                        tint: Theme.fgDim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No results for “" + launcher.query.trim() + "”"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
