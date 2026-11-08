import QtQuick
import QtQuick.Layouts
import ".."

// GNOME 46 style "pill" quick toggle: icon + title + status. On is painted
// with the accent; off, with the popup's neutral surface.
Rectangle {
    id: root
    property string icon: ""
    property url iconSource: ""
    property string label: ""
    property string sublabel: ""
    property bool checked: false
    // Trailing arrow to expand something below (e.g. a settings row).
    property bool expandable: false
    property bool expanded: false
    signal toggled(bool value)
    signal expandClicked

    implicitHeight: 56
    implicitWidth: 160
    radius: height / 2
    color: root.checked ? (mouse.containsMouse ? Theme.accentHover : Theme.accent)
                        : (mouse.containsMouse ? Theme.cardHoverBg : Theme.cardBg)
    opacity: root.enabled ? 1 : 0.4
    scale: mouse.pressed ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    readonly property color contentColor: root.checked ? Theme.accentFg : Theme.fg

    // Below the content so the expand arrow gets its own clicks.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: root.expandable ? 8 : 14
        spacing: 10

        SymbolicIcon {
            name: root.icon
            source: root.iconSource
            size: 18
            tint: root.contentColor
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.contentColor
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.sublabel.length > 0
                text: root.sublabel
                color: root.contentColor
                opacity: 0.75
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        IconButton {
            visible: root.expandable
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 30
            implicitHeight: 30
            iconSize: 12
            flat: true
            icon: "pan-end-symbolic"
            tint: root.contentColor
            rotation: root.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            onClicked: root.expandClicked()
        }
    }
}
