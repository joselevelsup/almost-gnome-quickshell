pragma Singleton
import Quickshell
import QtQuick

// Launches through umbriel's `spawn`, so apps are children of the compositor,
// not of Quickshell: a shell restart or crash won't take apps opened from the
// dock or the app grid with it.
QtObject {
    // umbriel runs the words as one sh command, so callers pass only words
    // that need no quoting.
    function spawn(words) { Quickshell.execDetached(["umbriel", "msg", "spawn"].concat(words)) }

    function launch(entry) {
        if (!entry) return
        if (/^[A-Za-z0-9._-]+$/.test(entry.id)) spawn(["gtk-launch", entry.id])
        else entry.execute()
    }
}
