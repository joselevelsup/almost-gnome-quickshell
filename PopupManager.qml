pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tracks which bar popup is open ("calendar", "quicksettings", ... or "").
// Only one can be open at a time, as in GNOME Shell.
QtObject {
    id: mgr
    property string current: ""
    // Timestamp of the last popup change: hot corners use it to avoid
    // reopening what the user just closed.
    property double lastChange: 0

    function open(name) { mgr.current = mgr.current === name ? "" : name }
    function close() { mgr.current = "" }
    onCurrentChanged: mgr.lastChange = Date.now()

    // Starts the lock screen (lock.qml) as its own instance, through umbriel so
    // it isn't a child of the shell.
    function lockScreen() {
        mgr.close()
        var path = Quickshell.shellPath("lock.qml")
        // umbriel runs spawn through sh; the path is single-quoted.
        if (path.indexOf("'") !== -1) { console.warn("Can't lock: quote in path", path); return }
        AppLauncher.spawn(["qs", "-d", "-p", "'" + path + "'"])
    }

    // For umbriel keybinds, e.g. `"Mod+W" = "spawn qs ipc call launcher toggle"`.
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

    property IpcHandler launcherIpc: IpcHandler {
        target: "launcher"
        function toggle(): void { mgr.open("launcher") }
        function open(): void { mgr.current = "launcher" }
        function close(): void { if (mgr.current === "launcher") mgr.close() }
    }
}
