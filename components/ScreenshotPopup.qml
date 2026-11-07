import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import QtQuick
import QtQuick.Layouts
import ".."

// GNOME-style screenshot panel: bottom center, with the mode (selection,
// screen or window), delay, pointer and the shutter button. Opens from
// Quick Settings or over IPC (`qs ipc call screenshot toggle`, e.g. bound
// to Print).
//
// A script (slurp + grim) takes the capture: it is saved to
// Pictures/Screenshots, copied to the clipboard and announced with a
// notification. Enter captures, Esc closes, ←/→ change mode.
PanelWindow {
    id: root
    WlrLayershell.namespace: "quickshell:popup:screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: PopupManager.current === "screenshot"
    anchors.bottom: true
    // Above the dock (64 px + 8 margin) when it's visible.
    margins.bottom: 88
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 460
    implicitHeight: card.implicitHeight

    // Preferences: kept while the shell runs.
    property string mode: "region" // region | screen | window
    property int delay: 0
    property bool showPointer: false

    readonly property var modes: [
        { value: "region", label: "Selection", icon: "edit-select-all-symbolic" },
        { value: "screen", label: "Screen", icon: "video-display-symbolic" },
        { value: "window", label: "Window", icon: "focus-windows-symbolic" }
    ]
    readonly property string hint: root.mode === "region" ? "Drag to select an area, or click for the whole monitor"
        : root.mode === "window" ? "You'll click the window next"
        : "Captures monitor " + (I3.focusedMonitor ? I3.focusedMonitor.name : "")

    function cycleMode(delta) {
        var i = root.modes.findIndex(m => m.value === root.mode)
        root.mode = root.modes[(i + delta + root.modes.length) % root.modes.length].value
    }

    // $1 mode, $2 delay (s), $3 pointer (0/1), $4 monitor, $5 accent (rrggbb)
    readonly property string script:
        "mode=$1; delay=$2; cursor=$3; mon=$4; acc=$5; " +
        // Let the panel disappear before selecting/capturing.
        "sleep 0.3; " +
        "sl() { slurp -c \"${acc}ff\" -s \"${acc}33\" -b 00000055 -w 2 \"$@\"; }; " +
        "case \"$mode\" in " +
        // -o: a click without dragging takes the whole monitor instead of a point.
        "  region) g=$(sl -d -o) || exit 0 ;; " +
        "  window) g=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) " +
        "       | .rect | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"' | sl -r) || exit 0 ;; " +
        "esac; " +
        "[ \"$delay\" -gt 0 ] && sleep \"$delay\"; " +
        ". \"${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs\" 2>/dev/null; " +
        "d=\"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\"; mkdir -p \"$d\"; " +
        "f=\"$d/Screenshot From $(date '+%Y-%m-%d %H-%M-%S').png\"; " +
        "c=; [ \"$cursor\" = 1 ] && c=-c; " +
        "if [ \"$mode\" = screen ]; then grim $c -o \"$mon\" \"$f\"; else grim $c -g \"$g\" \"$f\"; fi && " +
        "wl-copy < \"$f\" && " +
        "notify-send -a 'Screenshot' -i \"$f\" 'Screenshot captured' 'You can paste the image from the clipboard.'"

    function capture() {
        var mon = I3.focusedMonitor ? I3.focusedMonitor.name : ""
        var acc = String(Theme.accent).replace("#", "").slice(-6)
        PopupManager.close()
        Quickshell.execDetached(["sh", "-c", root.script, "sh",
            root.mode, String(root.delay), root.showPointer ? "1" : "0", mon, acc])
    }

    onVisibleChanged: if (visible) { card.opacity = 0; card.y = 6; openAnim.restart(); keys.forceActiveFocus() }
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape: PopupManager.close(); break
            case Qt.Key_Return:
            case Qt.Key_Enter: root.capture(); break
            case Qt.Key_Left: root.cycleMode(-1); break
            case Qt.Key_Right: root.cycleMode(1); break
            default: return
            }
            event.accepted = true
        }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 24
        height: implicitHeight
        radius: Theme.radius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.border

        Column {
            id: col
            anchors { fill: parent; margins: 12 }
            spacing: 10

            // ---- Header ----
            RowLayout {
                width: parent.width
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: "Screenshot"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                IconButton {
                    icon: "window-close-symbolic"
                    flat: true
                    onClicked: PopupManager.close()
                }
            }

            // ---- Mode ----
            Row {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.modes
                    delegate: TileButton {
                        required property var modelData
                        width: (col.width - 2 * 8) / 3
                        implicitHeight: 72
                        icon: modelData.icon
                        label: modelData.label
                        checked: root.mode === modelData.value
                        onClicked: root.mode = modelData.value
                    }
                }
            }
            Text {
                width: parent.width
                leftPadding: 4
                text: root.hint
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            // ---- Options ----
            SectionLabel { text: "Delay" }
            RowLayout {
                width: parent.width
                spacing: 8
                SegmentedControl {
                    Layout.fillWidth: true
                    model: [
                        { label: "None", value: "0" },
                        { label: "3 s", value: "3" },
                        { label: "5 s", value: "5" },
                        { label: "10 s", value: "10" }
                    ]
                    current: String(root.delay)
                    onSelected: value => root.delay = parseInt(value)
                }
                ChipButton {
                    icon: "input-mouse-symbolic"
                    text: "Show Pointer"
                    selected: root.showPointer
                    onClicked: root.showPointer = !root.showPointer
                }
            }

            // ---- Shutter ----
            Item {
                width: parent.width
                height: 64

                Rectangle {
                    id: shutter
                    anchors.centerIn: parent
                    width: 56
                    height: 56
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: shutterMouse.containsMouse ? Theme.accentHover : Theme.accent
                    scale: shutterMouse.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        radius: width / 2
                        color: shutterMouse.containsMouse ? Theme.accentHover : Theme.accent
                        Behavior on color { ColorAnimation { duration: 100 } }
                        SymbolicIcon {
                            anchors.centerIn: parent
                            name: "camera-photo-symbolic"
                            size: 18
                            tint: Theme.accentFg
                        }
                    }
                    MouseArea {
                        id: shutterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.capture()
                    }
                }

                Text {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "Enter to capture\nEsc to close"
                    horizontalAlignment: Text.AlignRight
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    lineHeight: 1.2
                }
            }
        }
    }
}
