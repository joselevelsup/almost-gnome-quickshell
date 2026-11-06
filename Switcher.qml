pragma Singleton
import Quickshell.Io
import QtQuick

// Alt+Tab window switcher state (most recently used first). Sway drives
// it over IPC: `qs ipc call winswitch next|prev` while Alt+Tab is held,
// `confirm` when Alt is released (see README for the bindings).
QtObject {
    id: switcher

    property bool winActive: false
    property var winList: []
    property int winIndex: 0

    function winStep(delta) {
        if (!switcher.winActive) {
            var all = Sway.windows
            if (all.length === 0) return
            switcher.winList = all
            switcher.winIndex = all.length > 1 ? (delta > 0 ? 1 : all.length - 1) : 0
            switcher.winActive = true
            return
        }
        switcher.winIndex = (switcher.winIndex + delta + switcher.winList.length) % switcher.winList.length
    }
    function winFinish(apply) {
        if (apply && switcher.winActive && switcher.winList.length > 0)
            Sway.focusWindow(switcher.winList[switcher.winIndex].id)
        switcher.winActive = false
    }

    property IpcHandler winIpc: IpcHandler {
        target: "winswitch"
        function next(): void { switcher.winStep(1) }
        function prev(): void { switcher.winStep(-1) }
        function confirm(): void { switcher.winFinish(true) }
        function cancel(): void { switcher.winFinish(false) }
    }

    // Safety net: if "confirm" (the modifier release) never arrives, don't
    // leave the overlay stuck on screen.
    property Timer winTimeout: Timer {
        interval: 8000
        running: switcher.winActive
        onTriggered: switcher.winFinish(false)
    }
}
