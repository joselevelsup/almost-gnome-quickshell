import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import ".."

// Overview estilo GNOME Activities / Mission Control: mosaico con todos
// los workspaces sobre el fondo de pantalla desenfocado. Cada tarjeta
// muestra el wallpaper y sus ventanas (posición y tamaño reales, escalados)
// como icono + título.
// Click en una ventana la enfoca; click en la tarjeta cambia de workspace;
// arrastrar una ventana la mueve a otro workspace (o a uno nuevo, con la
// tarjeta "+") sin perder el foco actual. Escribir busca aplicaciones
// (Enter abre la elegida). Esc limpia la búsqueda o cierra.
// Se abre desde la barra o por IPC: `qs ipc call overview toggle`.
PanelWindow {
    id: overview
    WlrLayershell.namespace: "quickshell:popup:overview"
    WlrLayershell.layer: WlrLayer.Overlay
    // Teclado exclusivo solo mientras está abierto, para Esc y 1–9.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: PopupManager.current === "overview"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"

    property var clients: []
    property string activeAddress: ""
    property var wsList: Hyprland.workspaces.values.filter(w => w.id > 0)
    // Workspace bajo el puntero mientras se arrastra una ventana (-1: ninguno).
    property int dropTarget: -1

    // ---- Búsqueda de aplicaciones ----
    // Como en GNOME: con el overview abierto, escribir busca apps; el
    // mosaico se reemplaza por los resultados.
    property string query: ""
    property int selIndex: 0
    // Grilla de aplicaciones (esquina caliente inferior izquierda): con el
    // campo vacío se listan todas las apps en vez del mosaico de workspaces.
    readonly property bool appGrid: overview.visible && PopupManager.appsMode
    readonly property bool searching: query.trim().length > 0 || overview.appGrid
    readonly property int resultCols: 6
    readonly property var results: {
        var q = query.trim().toLowerCase()
        var apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        if (q.length === 0) {
            if (!overview.appGrid) return []
            return apps.slice().sort((a, b) => a.name.localeCompare(b.name))
        }
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
    onQueryChanged: selIndex = 0

    function launch(entry) {
        if (!entry) return
        entry.execute()
        PopupManager.close()
    }
    function moveSelection(delta) {
        if (results.length === 0) return
        selIndex = Math.max(0, Math.min(results.length - 1, selIndex + delta))
    }
    readonly property int nextFreeId: wsList.reduce((m, w) => Math.max(m, w.id), 0) + 1

    // ---- Geometría del mosaico ----
    // Se busca la cantidad de columnas que da las tarjetas más grandes sin
    // salirse de la pantalla (referencia 1366×768).
    readonly property real aspect: width > 0 && height > 0 ? width / height : 16 / 9
    readonly property int gap: 24
    readonly property int labelH: 26
    readonly property real availW: width - 96
    readonly property real availH: height - 96 - 36
    readonly property int cardCount: wsList.length + 1
    readonly property var layout: {
        var best = { cols: 1, w: 0 }
        for (var cols = 1; cols <= cardCount; cols++) {
            var rows = Math.ceil(cardCount / cols)
            var w = Math.min((availW - (cols - 1) * gap) / cols,
                             (availH - rows * labelH - (rows - 1) * gap) / rows * aspect)
            if (w > best.w) best = { cols: cols, w: w }
        }
        // Con uno o dos workspaces no conviene que la tarjeta ocupe toda la pantalla.
        best.w = Math.floor(Math.min(best.w, availW * 0.42))
        return best
    }
    readonly property real cardW: layout.w
    readonly property real cardH: Math.round(cardW / aspect)

    function refresh() { clientsProc.running = true; activeProc.running = true }
    function focusWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        PopupManager.close()
    }
    function moveWindow(address, wsId) {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + wsId +
            ", window = \"address:" + address + "\", follow = false })")
        refreshLater.restart()
    }
    function cardAt(px, py) {
        for (var i = 0; i < grid.children.length; i++) {
            var c = grid.children[i]
            if (c.targetId === undefined) continue
            var p = c.mapToItem(backdrop, 0, 0)
            if (px >= p.x && px <= p.x + c.width && py >= p.y && py <= p.y + c.height) return c
        }
        return null
    }

    onVisibleChanged: {
        if (visible) {
            refresh()
            content.opacity = 0
            content.scale = 0.97
            openAnim.restart()
            searchInput.forceActiveFocus()
        } else {
            dropTarget = -1
            ghost.visible = false
            query = ""
        }
    }
    Timer { interval: 1000; running: overview.visible; repeat: true; onTriggered: overview.refresh() }
    // Tras una acción sobre Hyprland se relee el estado real.
    Timer { id: refreshLater; interval: 150; onTriggered: overview.refresh() }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { overview.clients = JSON.parse(text) } catch (e) { overview.clients = [] }
            }
        }
    }
    Process {
        id: activeProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { overview.activeAddress = JSON.parse(text).address || "" } catch (e) { overview.activeAddress = "" }
            }
        }
    }

    Item {
        id: backdrop
        anchors.fill: parent

        // ---- Fondo: wallpaper desenfocado y atenuado, como GNOME ----
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
        // El tinte sigue el esquema para que fg/fgDim se lean sobre cualquier fondo.
        Rectangle {
            anchors.fill: parent
            color: Theme.dark ? Theme.withAlpha("#000000", 0.55) : Theme.withAlpha("#ffffff", 0.62)
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

            // ---- Cabecera: buscador ----
            Column {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 20 }
                spacing: 6

                Rectangle {
                    width: 380
                    height: 36
                    radius: height / 2
                    color: Theme.popupBg
                    border.width: overview.searching ? 2 : 1
                    border.color: overview.searching ? Theme.accent : Theme.border
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    // Click en el campo no debe cerrar el overview.
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
                        text: overview.query
                        onTextEdited: overview.query = text
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
                                // Primero se limpia la búsqueda; con el campo
                                // vacío (o en la grilla), cierra.
                                if (overview.query.trim().length > 0) overview.query = ""
                                else PopupManager.close()
                                break
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                if (overview.searching) overview.launch(overview.results[overview.selIndex])
                                break
                            case Qt.Key_Left:  if (!overview.searching) return; overview.moveSelection(-1); break
                            case Qt.Key_Right: if (!overview.searching) return; overview.moveSelection(1); break
                            case Qt.Key_Up:    overview.moveSelection(-overview.resultCols); break
                            case Qt.Key_Down:  overview.moveSelection(overview.resultCols); break
                            case Qt.Key_Tab:   overview.moveSelection(1); break
                            default: return
                            }
                            event.accepted = true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Escribí para buscar aplicaciones"
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
                        visible: overview.searching
                        onClicked: { overview.query = ""; searchInput.forceActiveFocus() }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: overview.searching
                        ? "Enter para abrir · flechas para elegir · Esc para volver"
                        : "Arrastrá una ventana para moverla · Esc para cerrar"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // ---- Resultados de búsqueda ----
            Item {
                anchors.fill: parent
                anchors.topMargin: 96
                visible: overview.searching

                // Lista larga (grilla con todas las apps) → scroll.
                Flickable {
                    id: resultsFlick
                    anchors.fill: parent
                    anchors.topMargin: 16
                    anchors.bottomMargin: 16
                    contentWidth: width
                    contentHeight: resultsGrid.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Grid {
                        id: resultsGrid
                        x: Math.max(0, (resultsFlick.width - width) / 2)
                        y: 0
                        columns: Math.min(overview.resultCols, Math.max(1, overview.results.length))
                        spacing: 8

                        Repeater {
                            model: overview.results
                            delegate: Rectangle {
                                id: appTile
                                required property var modelData
                                required property int index
                                readonly property bool selected: index === overview.selIndex
                                width: 120
                                height: 112
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
                                    spacing: 8
                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        source: Quickshell.iconPath(appTile.modelData.icon, "application-x-executable")
                                        implicitSize: 48
                                    }
                                    Text {
                                        width: parent.width
                                        text: appTile.modelData.name
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
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
                                    onEntered: overview.selIndex = appTile.index
                                    onClicked: overview.launch(appTile.modelData)
                                }
                            }
                        }
                    }
                }

                // Estado vacío.
                Column {
                    anchors { top: parent.top; topMargin: 80; horizontalCenter: parent.horizontalCenter }
                    visible: overview.results.length === 0
                    spacing: 8
                    SymbolicIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "system-search-symbolic"
                        size: 32
                        tint: Theme.fgDim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Sin resultados para «" + overview.query.trim() + "»"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // ---- Mosaico ----
            Grid {
                id: grid
                visible: !overview.searching
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 30
                columns: overview.layout.cols
                columnSpacing: overview.gap
                rowSpacing: overview.gap

                Repeater {
                    model: overview.wsList
                    delegate: Column {
                        id: card
                        required property var modelData
                        readonly property int targetId: modelData.id
                        readonly property bool isActive: modelData.active
                        readonly property bool isDrop: overview.dropTarget === targetId
                        readonly property var winsHere: overview.clients
                            .filter(c => c.workspace.id === card.modelData.id && !c.hidden)
                            // Más reciente arriba; las flotantes sobre las tiled.
                            .sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID))
                        readonly property var mon: modelData.monitor
                        readonly property real mx: mon ? mon.x : 0
                        readonly property real my: mon ? mon.y : 0
                        readonly property real mw: mon ? mon.width / mon.scale : overview.width
                        readonly property real mh: mon ? mon.height / mon.scale : overview.height

                        spacing: 0

                        Item {
                            width: overview.cardW
                            height: overview.cardH

                            HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }

                            ClippingRectangle {
                                id: surface
                                anchors.fill: parent
                                radius: Theme.radius - 2
                                color: Theme.cardBg

                                Image {
                                    anchors.fill: parent
                                    source: Wallpaper.current ? "file://" + Wallpaper.current : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 480
                                    sourceSize.height: 270
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                // Resalta la tarjeta destino al arrastrar.
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.withAlpha(Theme.accent, 0.22)
                                    opacity: card.isDrop ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: overview.focusWorkspace(card.modelData.id)
                                }

                                // Estado vacío sobre la imagen.
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: card.winsHere.length === 0
                                    radius: height / 2
                                    width: emptyText.implicitWidth + 20
                                    height: emptyText.implicitHeight + 8
                                    color: Theme.withAlpha("#000000", 0.45)
                                    Text {
                                        id: emptyText
                                        anchors.centerIn: parent
                                        text: "Vacío"
                                        color: "#ffffff"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }

                                Repeater {
                                    model: card.winsHere
                                    delegate: Rectangle {
                                        id: winBox
                                        required property var modelData
                                        required property int index
                                        readonly property bool isFocused: modelData.address === overview.activeAddress
                                        readonly property bool hovered: dragArea.containsMouse && !dragging
                                        property bool dragging: false

                                        // Las ventanas se separan del borde lo mismo que en pantalla,
                                        // escalado, para que se lean como bloques sueltos.
                                        x: Math.max(3, (modelData.at[0] - card.mx) / card.mw * surface.width)
                                        y: Math.max(3, (modelData.at[1] - card.my) / card.mh * surface.height)
                                        width: Math.max(10, Math.min(surface.width - x - 3, modelData.size[0] / card.mw * surface.width))
                                        height: Math.max(10, Math.min(surface.height - y - 3, modelData.size[1] / card.mh * surface.height))
                                        z: card.winsHere.length - index
                                        radius: Theme.radius - 8
                                        color: Theme.popupBg
                                        border.width: isFocused ? 2 : 1
                                        border.color: (isFocused || hovered) ? Theme.accent : Theme.border
                                        opacity: dragging ? 0.3 : 1
                                        scale: dragArea.pressed && !dragging ? 0.97 : 1

                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 100 } }
                                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: Theme.hoverBg
                                            visible: winBox.hovered
                                        }

                                        IconImage {
                                            id: appIcon
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: titleText.visible ? -8 : 0
                                            source: Quickshell.iconPath(winBox.modelData.class, "application-x-executable")
                                            implicitSize: Math.max(12, Math.min(48, winBox.width * 0.35, winBox.height * 0.4))
                                        }
                                        Text {
                                            id: titleText
                                            anchors { top: appIcon.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                                            width: parent.width - 16
                                            visible: winBox.height > 64 && winBox.width > 60
                                            text: winBox.modelData.title || winBox.modelData.class
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: winBox.isFocused ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        MouseArea {
                                            id: dragArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: winBox.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            property point pressPos

                                            onPressed: mouse => {
                                                dragArea.pressPos = Qt.point(mouse.x, mouse.y)
                                                winBox.dragging = false
                                            }
                                            onPositionChanged: mouse => {
                                                if (!pressed) return
                                                var dx = mouse.x - dragArea.pressPos.x
                                                var dy = mouse.y - dragArea.pressPos.y
                                                if (!winBox.dragging && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
                                                    winBox.dragging = true
                                                    // El fantasma tiene tamaño fijo: una ventana grande
                                                    // no debe tapar las tarjetas destino.
                                                    ghost.width = Math.min(160, Math.max(96, winBox.width * 0.6))
                                                    ghost.height = Math.round(ghost.width * 0.62)
                                                    ghost.title = winBox.modelData.title || winBox.modelData.class
                                                    ghost.iconClass = winBox.modelData.class
                                                    ghost.visible = true
                                                }
                                                if (winBox.dragging) {
                                                    var abs = dragArea.mapToItem(backdrop, mouse.x, mouse.y)
                                                    ghost.x = abs.x - ghost.width / 2
                                                    ghost.y = abs.y - ghost.height / 2
                                                    var t = overview.cardAt(abs.x, abs.y)
                                                    overview.dropTarget = (t && t.targetId !== card.targetId) ? t.targetId : -1
                                                }
                                            }
                                            onReleased: {
                                                if (winBox.dragging) {
                                                    ghost.visible = false
                                                    if (overview.dropTarget !== -1)
                                                        overview.moveWindow(winBox.modelData.address, overview.dropTarget)
                                                    overview.dropTarget = -1
                                                } else if (containsMouse) {
                                                    Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + winBox.modelData.address + "\" })")
                                                    PopupManager.close()
                                                }
                                                winBox.dragging = false
                                            }
                                        }
                                    }
                                }
                            }

                            // Borde por encima de las ventanas (ClippingRectangle no lo pinta arriba).
                            Rectangle {
                                anchors.fill: parent
                                radius: surface.radius
                                color: "transparent"
                                border.width: (card.isActive || card.isDrop) ? 2 : 1
                                border.color: (card.isActive || card.isDrop) ? Theme.accent
                                    : cardHover.hovered ? Theme.fgDim : Theme.border
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }
                        }

                        // ---- Etiqueta bajo la tarjeta ----
                        Item {
                            width: overview.cardW
                            height: overview.labelH

                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 2
                                spacing: 6

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: card.isActive ? 14 : 6
                                    height: 6
                                    radius: 3
                                    color: card.isActive ? Theme.accent : Theme.fgDim
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.modelData.name
                                    color: card.isActive ? Theme.fg : Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: card.isActive ? Font.DemiBold : Font.Normal
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: card.winsHere.length > 0
                                    text: card.winsHere.length === 1 ? "1 ventana" : card.winsHere.length + " ventanas"
                                    color: Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }

                // ---- Tarjeta "nuevo workspace" ----
                Column {
                    id: addCard
                    readonly property int targetId: overview.nextFreeId
                    readonly property bool isDrop: overview.dropTarget === targetId

                    Rectangle {
                        width: overview.cardW
                        height: overview.cardH
                        radius: Theme.radius - 2
                        color: addCard.isDrop ? Theme.activeBg : addHover.hovered ? Theme.cardHoverBg : Theme.cardBg
                        border.width: addCard.isDrop ? 2 : 1
                        border.color: addCard.isDrop ? Theme.accent : Theme.border
                        scale: addArea.pressed ? 0.97 : 1

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            onClicked: overview.focusWorkspace(addCard.targetId)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            SymbolicIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "list-add-symbolic"
                                size: 32
                                tint: addCard.isDrop ? Theme.accent : Theme.fgDim
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: addCard.isDrop ? "Soltá para moverla aquí" : "Workspace nuevo"
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }
                    Item { width: overview.cardW; height: overview.labelH }
                }
            }
        }

        // ---- Fantasma de arrastre ----
        Rectangle {
            id: ghost
            visible: false
            z: 100
            radius: Theme.radius - 6
            color: Theme.toastBg
            border.width: 2
            border.color: Theme.accent
            property string title: ""
            property string iconClass: ""

            Column {
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 6
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: ghost.iconClass ? Quickshell.iconPath(ghost.iconClass, "application-x-executable") : ""
                    implicitSize: 32
                }
                Text {
                    width: parent.width
                    text: ghost.title
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
