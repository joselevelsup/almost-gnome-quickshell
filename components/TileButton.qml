import QtQuick
import ".."

// Square tile with icon on top and label below (window manager).
// `checkable` makes it behave as a toggle: on = accent.
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property bool checked: false
    property color tint: Theme.fg
    signal clicked

    implicitWidth: 88
    implicitHeight: 70
    radius: Theme.radius - 2
    color: tile.checked ? (mouse.containsMouse ? Theme.accentHover : Theme.accent)
                        : (mouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
    opacity: tile.enabled ? 1 : 0.4
    scale: mouse.pressed ? 0.96 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    readonly property color contentColor: tile.checked ? Theme.accentFg : tile.tint

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 6

        SymbolicIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.icon
            size: 20
            tint: tile.contentColor
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.contentColor
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: tile.checked ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
