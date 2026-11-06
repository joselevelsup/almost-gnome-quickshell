import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import ".."

// Adwaita symbolic icon (mono, recolorable) using the system icon theme
// via Quickshell.iconPath().
Item {
    id: root
    property string name: ""
    // Optional direct path to a bundled SVG (assets/), for icons missing
    // from the system theme.
    property url source: ""
    property color tint: Theme.fg
    property real size: Theme.iconSize

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        implicitSize: root.size
        source: root.source != "" ? root.source
            : root.name ? Quickshell.iconPath(root.name, true) : ""
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        // Symbolic SVGs use fill="currentColor" and Qt rasterizes them black;
        // brightness first turns them white, then colorization applies the
        // tint. Without brightness the icon stays black (invisible on the
        // dark bar).
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.tint
    }
}
