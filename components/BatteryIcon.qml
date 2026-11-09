import QtQuick
import ".."

// Battery status icon. Charging uses the Adwaita symbolic icon; on battery
// it is drawn here (same 16px geometry as Adwaita) so the fill can turn
// yellow at 15% and red at 5% while the outline stays white.
Item {
    id: root
    property real percentage: 1 // 0..1
    property bool charging: false
    property real size: Theme.iconSize
    readonly property real s: root.size / 16

    implicitWidth: size
    implicitHeight: size

    function fillColor(p) { return p <= 0.05 ? Theme.danger : p <= 0.15 ? Theme.warning : Theme.fg }

    SymbolicIcon {
        visible: root.charging
        anchors.fill: parent
        size: root.size
        name: {
            var step = Math.min(100, Math.max(0, Math.round(root.percentage * 10) * 10))
            return step === 100 ? "battery-level-100-charged-symbolic" : "battery-level-" + step + "-charging-symbolic"
        }
    }

    Item {
        visible: !root.charging
        anchors.fill: parent
        Rectangle { x: 6 * root.s; y: 0.5 * root.s; width: 4 * root.s; height: 2.5 * root.s; radius: root.s; color: Theme.fg }
        Rectangle {
            x: 2 * root.s; y: 2 * root.s; width: 12 * root.s; height: 14 * root.s; radius: 3 * root.s
            color: "transparent"; border.width: 2 * root.s; border.color: Theme.fg
        }
        Rectangle {
            // At least 2px so the red at a few percent stays visible.
            readonly property real h: root.s * Math.max(2, 8 * Math.min(1, root.percentage))
            x: 5 * root.s; y: 13 * root.s - h; width: 6 * root.s; height: h; radius: root.s
            color: root.fillColor(root.percentage)
        }
    }

    Component.onCompleted: console.assert(Qt.colorEqual(fillColor(0.04), Theme.danger)
        && Qt.colorEqual(fillColor(0.15), Theme.warning) && Qt.colorEqual(fillColor(0.5), Theme.fg),
        "BatteryIcon.fillColor self-check failed")
}
