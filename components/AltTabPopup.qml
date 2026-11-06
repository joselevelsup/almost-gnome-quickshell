import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

// Alt+Tab window switcher: shown while Alt is held, most recently used
// first; confirms when Alt is released. State lives in Switcher.qml.
PanelWindow {
    id: root
    WlrLayershell.namespace: "quickshell:popup:alttab"
    WlrLayershell.layer: WlrLayer.Overlay
    visible: Switcher.winActive
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    Rectangle {
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.border
        width: row.implicitWidth + 24
        height: row.implicitHeight + 24

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: Switcher.winList
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    width: 96
                    height: 96
                    radius: Theme.radius - 6
                    color: index === Switcher.winIndex ? Theme.activeBg : "transparent"
                    border.width: index === Switcher.winIndex ? 2 : 1
                    border.color: index === Switcher.winIndex ? Theme.accent : Theme.border

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Quickshell.iconPath(tile.modelData.appId, false)
                            implicitSize: 40
                            visible: status === Image.Ready
                        }
                        Text {
                            width: 84
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.title
                            color: index === Switcher.winIndex ? Theme.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
