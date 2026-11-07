import QtQuick
import ".."

// Small "chip" button: workspace numbers and the tiling assistant arrows
// in WindowControlPopup. `dot` adds a dot below the text (e.g. a workspace
// with windows). With both `icon` and `text` set, shows both (e.g.
// "Pointer" in the screenshot UI).
Rectangle {
    id: chip
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool dot: false
    signal clicked

    implicitWidth: Math.max(36, content.implicitWidth + 16)
    implicitHeight: 36
    radius: Theme.radius - 6
    color: chip.selected ? Theme.accent : (mouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
    opacity: chip.enabled || chip.selected ? 1 : 0.4
    scale: mouse.pressed ? 0.94 : 1

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on opacity { NumberAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    readonly property color contentColor: chip.selected ? Theme.accentFg : Theme.fg

    Row {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: chip.dot ? -2 : 0
        spacing: 6

        SymbolicIcon {
            visible: chip.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            size: 16
            tint: chip.contentColor
        }
        Text {
            visible: chip.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: chip.contentColor
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: chip.selected ? Font.Bold : Font.Normal
        }
    }
    Rectangle {
        visible: chip.dot
        width: 4
        height: 4
        radius: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        color: chip.contentColor
        opacity: 0.7
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
