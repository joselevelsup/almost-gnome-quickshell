pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Current wallpaper path, drawn by components/Background.qml. Saved to
// $XDG_STATE_HOME/quickshell/wallpaper so it survives restarts.
QtObject {
    id: root
    property string current: ""
    // Folder the picker lists (Settings → Background).
    readonly property string folder: Settings.options.wallpaperDir
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || ((Quickshell.env("HOME") || "/home/luis") + "/.local/state")) + "/quickshell"

    function apply(path) {
        if (path.length === 0) return
        root.current = path
        Quickshell.execDetached(["mkdir", "-p", root.stateDir])
        file.setText(path)
    }

    property FileView file: FileView {
        path: root.stateDir + "/wallpaper"
        // On first run the file doesn't exist: not an error.
        printErrors: false
        onLoaded: root.current = text().trim()
    }
}
