import QtQuick
import QtQuick.Layouts
import ".."

// GNOME Quick Settings style slider row: icon (clickable, e.g. to mute)
// + draggable bar that also responds to the scroll wheel.
Item {
    id: root
    property string icon: ""
    property real value: 0 // 0..1
    property bool muted: false
    property bool showValue: true
    // Trailing arrow to expand something below (e.g. audio outputs).
    property bool expandable: false
    property bool expanded: false
    signal valueEdited(real v)
    signal iconClicked
    signal expandClicked

    implicitHeight: 40

    readonly property real clamped: Math.min(1, Math.max(0, root.value))

    function setValue(v) {
        v = Math.max(0, Math.min(1, v))
        root.value = v
        root.valueEdited(v)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 6
        spacing: 8

        IconButton {
            icon: root.icon
            flat: true
            tint: root.muted ? Theme.fgDim : Theme.fg
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.iconClicked()
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            readonly property bool active: area.containsMouse || area.pressed
            readonly property real knobSize: track.active ? 18 : 16

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.trackBg
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Math.max(6, knob.x + knob.width / 2)
                height: 6
                radius: 3
                color: root.muted ? Theme.fgDim : Theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Rectangle {
                id: knob
                width: track.knobSize
                height: track.knobSize
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: (track.width - width) * root.clamped
                color: "#ffffff"
                border.width: 1
                border.color: Theme.withAlpha("#000000", 0.18)
                Behavior on width { NumberAnimation { duration: 90 } }
                Behavior on height { NumberAnimation { duration: 90 } }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.setValue(mouse.x / track.width)
                onPositionChanged: mouse => { if (pressed) root.setValue(mouse.x / track.width) }
                onWheel: wheel => root.setValue(root.clamped + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Text {
            visible: root.showValue
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.clamped * 100) + "%"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }

        IconButton {
            visible: root.expandable
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 28
            implicitHeight: 28
            iconSize: 12
            icon: "pan-end-symbolic"
            checked: root.expanded
            rotation: root.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            onClicked: root.expandClicked()
        }
    }
}
