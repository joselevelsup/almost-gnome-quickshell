import QtQuick
import QtQuick.Layouts
import ".."

// libadwaita-style settings row (SettingsWindow): title and optional
// subtitle on the left, the control (children) on the right.
Rectangle {
    id: row
    property string title: ""
    property string subtitle: ""
    default property alias control: slot.data

    implicitHeight: Math.max(54, texts.implicitHeight + 22)
    radius: Theme.radius - 6
    color: Theme.cardBg

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
        spacing: 12

        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: row.title
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: row.subtitle.length > 0
                text: row.subtitle
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Row {
            id: slot
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 8
        }
    }
}
