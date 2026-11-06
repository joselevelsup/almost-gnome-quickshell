import QtQuick
import ".."

// Round icon-only button (Quick Settings header, popup actions).
// `checked` paints it with the accent; `tint` colors the icon
// (e.g. Theme.danger for destructive actions).
Rectangle {
    id: btn
    property string icon: ""
    property url iconSource: ""
    property bool checked: false
    property bool flat: false
    property color tint: Theme.fg
    property real iconSize: 15
    signal clicked

    implicitWidth: 34
    implicitHeight: 34
    radius: height / 2
    color: btn.checked ? (mouse.containsMouse ? Theme.accentHover : Theme.accent)
         : mouse.containsMouse ? Theme.cardHoverBg
         : btn.flat ? "transparent" : Theme.cardBg
    opacity: btn.enabled ? 1 : 0.4
    scale: mouse.pressed ? 0.94 : 1

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on opacity { NumberAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    SymbolicIcon {
        anchors.centerIn: parent
        name: btn.icon
        source: btn.iconSource
        size: btn.iconSize
        tint: btn.checked ? Theme.accentFg : btn.tint
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
