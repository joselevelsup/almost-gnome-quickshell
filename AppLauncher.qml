pragma Singleton
import Quickshell
import Quickshell.I3
import QtQuick

// Launches .desktop entries through Sway's `exec`, so apps are children of
// the compositor, not of Quickshell: a shell restart or crash won't take
// apps opened from the dock or the overview with it.
QtObject {
    function launch(entry) {
        if (!entry) return
        // Sway runs `exec` through sh, so only pass ids that need no quoting.
        if (/^[A-Za-z0-9._-]+$/.test(entry.id)) I3.dispatch("exec gtk-launch " + entry.id)
        else entry.execute()
    }
}
