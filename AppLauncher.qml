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

    // ---- Modes: plain query searches apps, "/" files, ">" power ----
    // No trimStart(): the QML JS engine predates ES2019.
    function modeOf(query) {
        var q = query.replace(/^\s+/, "")
        return q.startsWith("/") ? "files" : q.startsWith(">") ? "power" : "apps"
    }

    // The query without its mode prefix.
    function termOf(query) { return query.replace(/^\s+/, "").slice(1).trim().toLowerCase() }

    // Same rows as the quick settings power menu, destructive last.
    readonly property var powerActions: [
        { icon: "system-lock-screen-symbolic", name: "Lock Screen", action: "lock" },
        { icon: "weather-clear-night-symbolic", name: "Suspend", action: "suspend" },
        { icon: "system-reboot-symbolic", name: "Restart", action: "reboot" },
        { icon: "system-log-out-symbolic", name: "Log Out", action: "logout" },
        { icon: "system-shutdown-symbolic", name: "Power Off", action: "poweroff" }
    ]

    // Mirrors the quick settings power menu: suspend and log out run at
    // once, reboot/power off go through the confirmation dialog.
    function runAction(action) {
        switch (action) {
        case "lock": PopupManager.lockScreen(); break
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); break
        case "reboot": PopupManager.openPower("reboot"); break
        case "logout": Umbriel.msg(["session-quit", "skip-confirmation"]); break
        case "poweroff": PopupManager.openPower("poweroff"); break
        }
    }

    // Unified results for both launchers: { icon, name, sub, run }.
    // Only reads FileSearch.results — popups bind to this, so calling
    // FileSearch.search here would create a re-evaluation loop.
    function tiles(query) {
        var mode = modeOf(query)
        var term = termOf(query)
        if (mode === "power")
            return powerActions
                .filter(a => term.length === 0 || a.name.toLowerCase().indexOf(term) !== -1)
                .map(a => ({ icon: a.icon, name: a.name, sub: "", run: () => AppLauncher.runAction(a.action) }))
        if (mode === "files") {
            // An empty term would list all of $HOME; ask for a name instead.
            if (term.length === 0) return []
            var home = Quickshell.env("HOME")
            return FileSearch.results.map(r => {
                var dir = r.path.slice(0, r.path.lastIndexOf("/"))
                return {
                    icon: r.isDir ? "folder" : "text-x-generic",
                    name: r.path.slice(r.path.lastIndexOf("/") + 1),
                    sub: dir.replace(home, "~"),
                    run: () => AppLauncher.openPath(r.path)
                }
            })
        }
        return AppLauncher.search(query, 30).map(e => ({
            icon: e.icon, name: e.name, sub: e.comment || e.genericName || "",
            run: () => AppLauncher.launch(e)
        }))
    }

    // FileSearch drops paths with quotes, so single quotes are safe in
    // umbriel's sh.
    function openPath(path) { AppLauncher.spawn(["xdg-open", "'" + path + "'"]) }

    Component.onCompleted: {
        console.assert(modeOf("/foo") === "files" && modeOf(">sus") === "power"
            && modeOf("foo bar") === "apps" && termOf(">  Sus") === "sus",
            "AppLauncher mode self-check failed")
    }
}
