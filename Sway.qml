pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.I3
import QtQuick

// Window list from `swaymsg -t get_tree`. Quickshell's I3 module covers
// workspaces and outputs, but not window geometry, so the overview, the
// Alt+Tab switcher and the dock read windows from here. Refreshes on
// every Sway window/workspace event.
QtObject {
    id: sway

    // Every window: { id, appId, title, rect: {x, y, width, height},
    // floating, focused, ws (workspace name) }. Most recently focused first.
    // shortcut: order comes from each container's `focus` list, so it is exact
    // within a workspace but only approximate across workspaces; track window
    // focus events if Alt+Tab ordering ever feels wrong.
    property var windows: []

    function refresh() { treeProc.running = true }

    // Sway command for a workspace by name, quoted.
    function workspaceCmd(name) {
        return "workspace \"" + String(name).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
    }
    function focusWindow(id) { I3.dispatch("[con_id=" + id + "] focus") }
    function moveWindow(id, wsName) {
        I3.dispatch("[con_id=" + id + "] move container to " + sway.workspaceCmd(wsName))
    }

    function parse(root) {
        var out = []
        function walk(node, ws) {
            if (node.type === "workspace") {
                if (node.name === "__i3_scratch") return
                ws = node.name
            } else if (ws !== null && node.pid !== undefined) {
                out.push({
                    id: node.id,
                    appId: node.app_id || (node.window_properties ? node.window_properties.class : "") || "",
                    title: node.name || "",
                    rect: node.rect,
                    floating: node.type === "floating_con",
                    focused: node.focused === true,
                    ws: ws
                })
                return
            }
            var focus = node.focus || []
            var kids = (node.nodes || []).concat(node.floating_nodes || [])
            kids.sort((a, b) => {
                var i = focus.indexOf(a.id), j = focus.indexOf(b.id)
                return (i < 0 ? 1e9 : i) - (j < 0 ? 1e9 : j)
            })
            for (var k = 0; k < kids.length; k++) walk(kids[k], ws)
        }
        walk(root, null)
        return out
    }

    property Process treeProc: Process {
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { sway.windows = sway.parse(JSON.parse(text)) } catch (e) { sway.windows = [] }
            }
        }
    }

    // Events arrive in bursts (e.g. close + focus); coalesce into one read.
    property Timer debounce: Timer { interval: 50; onTriggered: sway.refresh() }
    property I3IpcListener listener: I3IpcListener {
        subscriptions: ["window", "workspace"]
        onIpcEvent: sway.debounce.restart()
    }
    Component.onCompleted: sway.refresh()
}
