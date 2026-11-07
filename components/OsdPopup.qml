import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Volume/brightness pill at the bottom center, like GNOME's OSD.
// Appears when the value changes and hides itself (state in Osd.qml).
// Doesn't take clicks: indicator only.
PanelWindow {
    id: root
    WlrLayershell.namespace: "quickshell:toast"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.bottom: true
    // Above the dock (64 px + 8 margin) when it is visible.
    margins.bottom: 88
    exclusiveZone: 0
    focusable: false
    color: "transparent"
    mask: Region {}
    implicitWidth: 330
    implicitHeight: 48
    // Stays visible during the fade-out.
    visible: Osd.shown || pill.opacity > 0

    readonly property bool overAmp: Osd.kind === "volume" && Osd.value > 1.0
    readonly property string icon: {
        if (Osd.kind === "brightness") return "display-brightness-symbolic"
        if (Osd.muted || Osd.value <= 0) return "audio-volume-muted-symbolic"
        if (Osd.value < 0.34) return "audio-volume-low-symbolic"
        if (Osd.value < 0.67) return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.toastBg
        border.width: 1
        border.color: Theme.border
        opacity: Osd.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        SymbolicIcon {
            id: icon
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            name: root.icon
            size: 18
            tint: Osd.muted ? Theme.fgDim : Theme.fg
        }

        Text {
            id: pct
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(Osd.value * 100) + "%"
            color: Osd.muted ? Theme.fgDim : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }

        // Track: with volume over 100% the scale becomes 0–150% (the
        // wpctl -l 1.5 cap) and a tick marks where 100% is.
        Rectangle {
            id: track
            anchors { left: icon.right; right: pct.left; leftMargin: 14; rightMargin: 12; verticalCenter: parent.verticalCenter }
            height: 6
            radius: 3
            color: Theme.trackBg
            readonly property real scaleMax: root.overAmp ? 1.5 : 1.0

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(height, parent.width * Math.min(1, Osd.value / track.scaleMax))
                visible: Osd.value > 0
                color: Osd.muted ? Theme.fgDim : Theme.accent
                Behavior on width { NumberAnimation { duration: 100 } }
            }
            Rectangle {
                visible: root.overAmp
                x: parent.width / track.scaleMax - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 12
                radius: 1
                color: Theme.fg
            }
        }
    }
}
