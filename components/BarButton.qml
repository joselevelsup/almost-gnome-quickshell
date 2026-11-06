import QtQuick
import ".."

// Generic bar button: rounded background highlighted on hover or while
// its popup is open. Content (icon, text, or both) is passed as children.
Rectangle {
    id: btn
    default property alias content: row.data
    property bool active: false
    property alias spacing: row.spacing
    property alias containsMouse: mouse.containsMouse

    signal clicked
    signal rightClicked

    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 24
    radius: height / 2
    // GNOME highlights open panel buttons in white, not the accent.
    color: btn.active ? Theme.withAlpha("#ffffff", 0.22) : (mouse.containsMouse ? Theme.hoverBg : "transparent")

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                btn.rightClicked()
            else
                btn.clicked()
        }
    }
}
