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
    // Hidden when empty so it adds no gap in the bar's RowLayout.
    visible: SystemTray.items.values.length > 0

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

            // Single-color icons (e.g. wayscriber-symbolic) render black;
            // SymbolicIcon recolors them white like the bar's own icons.
            readonly property bool symbolic: String(trayItem.modelData.icon).indexOf("-symbolic") !== -1
            IconImage {
                anchors.centerIn: parent
                visible: !trayItem.symbolic
                implicitSize: 16
                source: trayItem.modelData.icon
            }
            SymbolicIcon {
                anchors.centerIn: parent
                visible: trayItem.symbolic
                source: trayItem.symbolic ? trayItem.modelData.icon : ""
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
