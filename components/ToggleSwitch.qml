import QtQuick
import ".."

// GNOME/libadwaita style toggle switch.
Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: sw.checked ? Theme.accent : Theme.trackBg
    border.width: sw.checked ? 0 : 1
    border.color: Theme.border

    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: parent.height - 4
        height: parent.height - 4
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: sw.checked ? parent.width - width - 2 : 2
        color: "#ffffff"
        Behavior on anchors.leftMargin { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        // Don't mutate sw.checked here: this is a "controlled" component, its
        // real value comes from outside. Setting it locally breaks the binding
        // to the real state (Wi-Fi/Bluetooth/DND) and the switch goes out of
        // sync after the first click.
        onClicked: sw.toggled(!sw.checked)
    }
}
