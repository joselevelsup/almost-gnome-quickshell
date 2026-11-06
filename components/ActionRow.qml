import QtQuick
import QtQuick.Layouts
import ".."

// Clickable row with icon + label, for menus (power, settings...).
Item {
    id: root
    property string icon: ""
    property string label: ""
    property color tint: Theme.fg
    signal clicked

    implicitHeight: 38
    implicitWidth: 200
    opacity: root.enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: 100 } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius - 6
        color: mouse.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        SymbolicIcon { name: root.icon; tint: root.tint; Layout.alignment: Qt.AlignVCenter }
        Text {
            text: root.label
            elide: Text.ElideRight
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: 12
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
