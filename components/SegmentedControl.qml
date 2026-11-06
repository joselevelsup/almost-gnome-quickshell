import QtQuick
import QtQuick.Layouts
import ".."

// Segmented selector (one active option among several), libadwaita style.
// model: [{ label: "Tabbed", value: "tabbed" }, ...]
Rectangle {
    id: root
    property var model: []
    property string current: ""
    signal selected(string value)

    implicitHeight: 32
    radius: height / 2
    color: Theme.cardBg

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        Repeater {
            model: root.model
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool active: root.current === seg.modelData.value
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: height / 2
                color: seg.active ? Theme.accent : (mouse.containsMouse ? Theme.hoverBg : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.active ? Theme.accentFg : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: seg.active ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!seg.active) root.selected(seg.modelData.value)
                }
            }
        }
    }
}
