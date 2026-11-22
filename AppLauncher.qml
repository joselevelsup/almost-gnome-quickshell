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

    // Shared by the app grid and the spotlight. An empty query lists every
    // app alphabetically; otherwise the best `limit` matches.
    function search(query, limit) {
        var q = query.trim().toLowerCase()
        var apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        if (q.length === 0) return apps.slice().sort((a, b) => a.name.localeCompare(b.name))
        function score(e) {
            var n = (e.name || "").toLowerCase()
            if (n.startsWith(q)) return 100
            if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
            if (n.indexOf(q) !== -1) return 60
            var extra = [e.genericName || "", (e.keywords || []).join(" "), e.id || ""].join(" ").toLowerCase()
            if (extra.indexOf(q) !== -1) return 40
            if ((e.comment || "").toLowerCase().indexOf(q) !== -1) return 20
            return 0
        }
        return apps
            .map(e => ({ entry: e, score: score(e) }))
            .filter(r => r.score > 0)
            .sort((a, b) => (b.score - a.score) || a.entry.name.localeCompare(b.entry.name))
            .slice(0, limit)
            .map(r => r.entry)
    }
}
