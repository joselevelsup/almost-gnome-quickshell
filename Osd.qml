pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// State of the volume and brightness OSD (on-screen display), like GNOME's.
// It doesn't listen for keys: it watches the real values (Pipewire and
// sysfs), so it shows up whether the change comes from the compositor's
// media keys, wpctl/light in a terminal or another app.
// Drawn by components/OsdPopup.qml.
QtObject {
    id: osd

    // "volume" | "brightness"
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false

    // The first values at shell startup aren't user changes.
    property bool ready: false
    property Timer readyTimer: Timer { interval: 1500; running: true; onTriggered: osd.ready = true }
    property Timer hideTimer: Timer { interval: 1500; onTriggered: osd.shown = false }

    function show(kind, value, muted) {
        osd.kind = kind
        osd.value = value
        osd.muted = muted
        // With Quick Settings open, the slider already shows the value.
        if (!osd.ready || PopupManager.current === "quicksettings") return
        osd.shown = true
        osd.hideTimer.restart()
    }

    // ---- Volume ----
    readonly property var sink: Pipewire.defaultAudioSink
    property PwObjectTracker tracker: PwObjectTracker { objects: osd.sink ? [osd.sink] : [] }
    property Connections audioWatch: Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumeChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
        function onMutedChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
    }

    // ---- Brightness ----
    // Writing the sysfs file (light) triggers inotify, so FileView
    // with watchChanges is enough; no polling needed.
    property string backlight: ""
    property real maxBrightness: 0
    property Process findBacklight: Process {
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$d\" && break; done"]
        running: true
        stdout: StdioCollector { onStreamFinished: osd.backlight = text.trim() }
    }
    property FileView maxFile: FileView {
        path: osd.backlight ? osd.backlight + "/max_brightness" : ""
        onLoaded: osd.maxBrightness = parseInt(text())
    }
    property FileView brightnessFile: FileView {
        path: osd.backlight ? osd.backlight + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var cur = parseInt(text())
            if (osd.maxBrightness > 0 && !isNaN(cur)) osd.show("brightness", cur / osd.maxBrightness, false)
        }
    }
}
