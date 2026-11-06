import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// Wallpaper picker (Settings → Background): large preview of the current
// wallpaper (or the one under the pointer) and a scrollable grid with the
// images in Wallpaper.folder. Drawn by Background.qml; Wallpaper.qml
// remembers the choice.
Column {
    id: popup
    spacing: 10

    readonly property string wallpaperDir: Wallpaper.folder
    property var files: []
    property string hovered: ""
    readonly property string previewPath: popup.hovered || Wallpaper.current

    readonly property int columns: 3
    readonly property int gridSpacing: 8
    readonly property real tileWidth: (popup.width - popup.gridSpacing * (popup.columns - 1)) / popup.columns
    readonly property real tileHeight: Math.round(popup.tileWidth * 9 / 16)
    readonly property int maxRows: 4

    function prettyName(path) {
        if (!path) return ""
        var name = path.substring(path.lastIndexOf("/") + 1)
        return name.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ")
    }
    function shuffle() {
        var pool = popup.files.filter(f => f !== Wallpaper.current)
        if (pool.length === 0) return
        Wallpaper.apply(pool[Math.floor(Math.random() * pool.length)])
    }

    function refresh() { listProc.running = true }
    onVisibleChanged: {
        popup.hovered = ""
        if (popup.visible) popup.refresh()
    }
    onWallpaperDirChanged: popup.refresh()

    Process {
        id: listProc
        command: ["find", popup.wallpaperDir, "-maxdepth", "1", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n").filter(l => /\.(png|jpe?g|webp|bmp|gif)$/i.test(l))
                lines.sort()
                popup.files = lines
            }
        }
    }

    // ---- Header ----
    RowLayout {
        width: parent.width
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 0
            Text {
                text: popup.files.length === 1 ? "1 image" : popup.files.length + " images"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        IconButton {
            icon: "media-playlist-shuffle-symbolic"
            enabled: popup.files.length > 1
            onClicked: popup.shuffle()
        }
        IconButton {
            icon: "folder-symbolic"
            onClicked: Quickshell.execDetached(["xdg-open", popup.wallpaperDir])
        }
    }

    // ---- Preview ----
    ClippingRectangle {
        width: parent.width
        height: Math.round(width * 9 / 16)
        radius: Theme.radius - 2
        color: Theme.cardBg

        Image {
            id: preview
            anchors.fill: parent
            source: popup.previewPath ? "file://" + popup.previewPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 800
            sourceSize.height: 450
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Column {
            visible: preview.status !== Image.Ready
            anchors.centerIn: parent
            spacing: 8
            SymbolicIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "preferences-desktop-wallpaper-symbolic"
                size: 32
                tint: Theme.fgDim
            }
            Text {
                visible: popup.files.length > 0
                text: "Hover over an image to preview it"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        // Footer with the file name, over a gradient so it's readable on top
        // of any image.
        Rectangle {
            visible: popup.previewPath.length > 0
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.withAlpha("#000000", 0.6) }
            }

            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.margins: 10
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: popup.prettyName(popup.previewPath)
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: popup.previewPath === Wallpaper.current
                    implicitWidth: badge.implicitWidth + 14
                    implicitHeight: 18
                    radius: height / 2
                    color: Theme.accent
                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: "Current"
                        color: Theme.accentFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    // ---- Empty state ----
    Column {
        visible: popup.files.length === 0
        width: parent.width
        topPadding: 6
        bottomPadding: 6
        spacing: 4
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No images yet"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Add PNG, JPG or WebP files to ~/Pictures/Wallpapers"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }

    // ---- Grid ----
    Flickable {
        id: flick
        visible: popup.files.length > 0
        width: parent.width
        readonly property int rows: Math.ceil(popup.files.length / popup.columns)
        height: Math.min(rows, popup.maxRows) * (popup.tileHeight + popup.gridSpacing) - popup.gridSpacing
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: grid
            width: parent.width
            columns: popup.columns
            spacing: popup.gridSpacing

            Repeater {
                model: popup.files
                delegate: Item {
                    id: tile
                    required property string modelData
                    readonly property bool current: Wallpaper.current === tile.modelData
                    width: popup.tileWidth
                    height: popup.tileHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.radius - 6
                        color: Theme.cardBg
                        scale: mouse.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        Image {
                            anchors.fill: parent
                            source: "file://" + tile.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 240
                            sourceSize.height: 135
                        }
                        // Slightly darkens tiles that aren't hovered, to
                        // focus the one under the pointer.
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: mouse.containsMouse ? 0 : 0.12
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    // Selection / hover ring (inside the tile: the
                    // Flickable clips anything that sticks out).
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius - 6
                        color: "transparent"
                        border.width: tile.current ? 3 : 2
                        border.color: tile.current ? Theme.accent : Theme.withAlpha(Theme.fg, 0.5)
                        opacity: tile.current || mouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    // Checkmark for the current wallpaper
                    Rectangle {
                        visible: tile.current
                        anchors { top: parent.top; right: parent.right; margins: 5 }
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.accent
                        SymbolicIcon {
                            anchors.centerIn: parent
                            name: "object-select-symbolic"
                            size: 11
                            tint: Theme.accentFg
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) popup.hovered = tile.modelData
                            else if (popup.hovered === tile.modelData) popup.hovered = ""
                        }
                        onClicked: Wallpaper.apply(tile.modelData)
                    }
                }
            }
        }
    }
}
