pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Tracks which bar popup is open ("calendar", "quicksettings", ... or "").
// Only one can be open at a time, as in GNOME Shell.
QtObject {
    id: mgr
    property string current: ""
    // Timestamp of the last popup change: hot corners use it to avoid
    // reopening what the user just closed.
    property double lastChange: 0
    // true → the overview opens as the app grid (bottom-left corner)
    // instead of the workspace mosaic.
    property bool appsMode: false

    function open(name) {
        // With the app grid open, the overview toggle switches to the
        // mosaic instead of closing.
        if (mgr.current === name) {
            if (name === "overview" && mgr.appsMode) mgr.appsMode = false
            else mgr.close()
        } else { mgr.appsMode = false; mgr.current = name }
    }
    function openApps() {
        mgr.appsMode = true
        mgr.current = "overview"
    }
    function close() { mgr.current = ""; mgr.appsMode = false }
    onCurrentChanged: mgr.lastChange = Date.now()

    // Starts the lock screen (lock.qml) as its own instance, through Sway so it
    // isn't a child of the shell.
    function lockScreen() {
        mgr.close()
        var path = Quickshell.shellPath("lock.qml")
        // Sway runs exec through sh; the path is single-quoted.
        if (path.indexOf("'") !== -1) { console.warn("Can't lock: quote in path", path); return }
        I3.dispatch("exec qs -d -p '" + path + "'")
    }

    // For Sway keybindings, e.g. `bindsym $mod+d exec qs ipc call overview toggle`.
    property IpcHandler screenshotIpc: IpcHandler {
        target: "screenshot"
        function toggle(): void { mgr.open("screenshot") }
    }

    property IpcHandler wallpaperIpc: IpcHandler {
        target: "wallpaper"
        function toggle(): void { Settings.openWindow("background") }
    }

    // `qs ipc call settings open`, or `openPage <name>` with one of: datetime,
    // topbar, appearance, background, dock, nightlight.
    property IpcHandler settingsIpc: IpcHandler {
        target: "settings"
        function open(): void { mgr.close(); Settings.openWindow("") }
        function openPage(page: string): void { mgr.close(); Settings.openWindow(page) }
        function close(): void { Settings.windowOpen = false }
    }

    property IpcHandler lockIpc: IpcHandler {
        target: "lock"
        function lock(): void { mgr.lockScreen() }
    }

    property IpcHandler overviewIpc: IpcHandler {
        target: "overview"
        function toggle(): void { mgr.open("overview") }
        function open(): void { mgr.appsMode = false; mgr.current = "overview" }
        // App grid, e.g. `qs ipc call overview apps`.
        function apps(): void { mgr.openApps() }
        function close(): void { if (mgr.current === "overview") mgr.close() }
    }
}
