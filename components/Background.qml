import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Desktop background, one per screen. A new wallpaper crossfades over the
// old one once it has loaded, like GNOME.
PanelWindow {
    id: bg
    WlrLayershell.namespace: "quickshell:background"
    WlrLayershell.layer: WlrLayer.Background
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "#000000"

    readonly property string source: Wallpaper.current ? "file://" + Wallpaper.current : ""
    property Image front: imgA
    readonly property Image back: front === imgA ? imgB : imgA

    onSourceChanged: bg.back.source = bg.source
    Component.onCompleted: bg.back.source = bg.source

    function reveal(img) {
        if (img !== bg.back || img.status !== Image.Ready) return
        img.z = 1
        bg.front.z = 0
        bg.front = img
        fade.restart()
    }

    NumberAnimation {
        id: fade
        target: bg.front
        property: "opacity"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.InOutQuad
        // Free the old image once it's fully covered (not when a newer
        // wallpaper interrupts the fade: restart() also emits finished).
        onFinished: if (bg.front.opacity === 1) bg.back.source = ""
    }

    component Slide: Image {
        id: slide
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0
        // Decode at screen resolution, not the file's.
        sourceSize.width: bg.width * (bg.screen ? bg.screen.devicePixelRatio : 1)
        sourceSize.height: bg.height * (bg.screen ? bg.screen.devicePixelRatio : 1)
        onStatusChanged: bg.reveal(slide)
    }
    Slide { id: imgA }
    Slide { id: imgB }
}
