import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."

// Static blur, like Blur my Shell's static mode: the blurred wallpaper slice
// under the parent, tinted. The compositor isn't asked to blur behind it, so the
// slice is lined up from where the host window sits on screen. Put it in a
// Rectangle whose color is transparent while Settings.options.blur is on; it
// draws below the parent's border. Only for PanelWindow hosts.
ClippingRectangle {
    id: root
    property color tint: Theme.withAlpha(Theme.popupBg, 0.6)

    readonly property var win: QsWindow.window
    readonly property real sw: win && win.screen ? win.screen.width : 0
    readonly property real sh: win && win.screen ? win.screen.height : 0
    // Wayland doesn't tell clients where their surface is, so derive it from
    // the layer-shell anchors/margins. The bar's exclusive zone pushes the
    // other top-anchored surfaces down.
    readonly property real winX: !win ? 0
        : win.anchors.left ? win.margins.left
        : win.anchors.right ? sw - win.margins.right - win.width
        : (sw - win.width) / 2
    readonly property real winY: {
        if (!win) return 0
        var zone = win.exclusiveZone > 0 ? 0 : Theme.barHeight
        if (win.anchors.top) return zone + win.margins.top
        // shortcut: ignores the dock's reserved space (auto-hide off), so bottom popups sample a slightly lower slice; fine under heavy blur.
        if (win.anchors.bottom) return sh - win.margins.bottom - win.height
        return zone + (sh - zone - win.height) / 2
    }
    // Listed dependencies re-run mapToItem when the host moves (dock sliding
    // in, popup open animation, toasts reflowing).
    readonly property point pos: {
        parent.x; parent.y; parent.width; parent.height
        if (parent.parent) { parent.parent.x; parent.parent.y }
        return parent.mapToItem(null, 0, 0)
    }

    visible: Settings.options.blur
    anchors.fill: parent
    z: -1
    radius: parent.radius
    color: "#000000"

    Image {
        id: img
        x: -(root.winX + root.pos.x)
        y: -(root.winY + root.pos.y)
        width: root.sw
        height: root.sh
        source: root.visible && Wallpaper.current ? "file://" + Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Small decode is enough under heavy blur; same aspect as the screen
        // so the crop matches Background.qml.
        sourceSize.width: root.sw / 4
        sourceSize.height: root.sh / 4
        visible: false
    }
    MultiEffect {
        x: img.x
        y: img.y
        width: img.width
        height: img.height
        source: img
        visible: img.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 48
    }
    Rectangle {
        anchors.fill: parent
        color: root.tint
    }
}
