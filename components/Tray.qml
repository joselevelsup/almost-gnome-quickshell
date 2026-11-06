import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import ".."

// System tray (background app icons). Left click activates the item;
// the context menu (right click) is not implemented.
Row {
    id: tray
    spacing: 2

    Repeater {
        model: SystemTray.items.values
        delegate: Item {
            id: trayItem
            required property var modelData
            implicitWidth: Theme.barHeight - 10
            implicitHeight: Theme.barHeight - 10

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius - 4
                color: mouse.containsMouse ? Theme.hoverBg : "transparent"
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.MiddleButton)
                        trayItem.modelData.secondaryActivate()
                    else
                        trayItem.modelData.activate()
                }
            }
        }
    }
}
