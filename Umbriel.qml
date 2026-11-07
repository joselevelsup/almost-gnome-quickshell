pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Windows and workspaces from `umbriel subscribe`, which prints a full
// snapshot as one JSON line on every change. The bar, the Alt+Tab
// switcher and the dock read from here.
QtObject {
    id: umb

    // Every window: { id, appId, title, rect: {x, y, width, height},
    // floating, focused, ws (workspace name), output }. Most recently focused first.
    property var windows: []
    // Every workspace: { id, name, index, output, active, focused, occupied }.
    property var workspaces: []
    readonly property var focusedWorkspace: workspaces.find(w => w.focused) || null
    readonly property string focusedOutput: focusedWorkspace ? focusedWorkspace.output : ""

    // Window ids, most recently focused first. umbriel doesn't report focus
    // history, so it is tracked here from the focused flag.
    property var mru: []
    property var rawWindows: []

    function msg(args) { Quickshell.execDetached(["umbriel", "msg"].concat(args)) }
    function focusWindow(id) { msg(["window-focus", id]) }

    function rebuild() {
        var names = {}
        umb.workspaces.forEach(w => names[w.id] = w.name)
        var focused = umb.rawWindows.find(w => w.active)
        var mru = umb.mru.filter(id => umb.rawWindows.some(w => w.id === id))
        if (focused && mru[0] !== focused.id) mru = [focused.id].concat(mru.filter(id => id !== focused.id))
        umb.rawWindows.forEach(w => { if (mru.indexOf(w.id) < 0) mru.push(w.id) })
        umb.mru = mru
        umb.windows = umb.rawWindows
            .filter(w => w.workspace && !w.scratchpad)
            .map(w => ({
                id: w.id,
                appId: w.app_id || "",
                title: w.title || "",
                rect: { x: w.x, y: w.y, width: w.w, height: w.h },
                floating: w.floating,
                focused: w.active,
                ws: names[w.workspace] || "",
                output: w.output
            }))
            .sort((a, b) => mru.indexOf(a.id) - mru.indexOf(b.id))
    }

    property Process events: Process {
        command: ["umbriel", "subscribe", "windows,workspaces"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var ev
                try { ev = JSON.parse(line) } catch (e) { return }
                if (ev.event === "workspaces") {
                    umb.workspaces = ev.data.map(w => ({
                        id: w.id, name: w.name, index: w.index, output: w.output,
                        active: w.active, focused: w.focused, occupied: w.occupied
                    }))
                } else if (ev.event === "windows") {
                    umb.rawWindows = ev.data
                }
                umb.rebuild()
            }
        }
        // Restart if the stream ends (e.g. umbriel restarted its IPC).
        onRunningChanged: if (!running) umb.restartTimer.restart()
    }
    property Timer restartTimer: Timer { interval: 1000; onTriggered: umb.events.running = true }
}
