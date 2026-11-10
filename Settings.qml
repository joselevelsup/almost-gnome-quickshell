pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User settings, edited in the Settings window (SettingsWindow.qml) and
// saved to $XDG_STATE_HOME/quickshell/settings.json on every change.
// Defaults match vanilla GNOME.
QtObject {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"

    property JsonAdapter options: JsonAdapter {
        // IANA zone for the top bar clock and calendar; "" = system timezone.
        property string timezone: ""
        property bool clock24h: true
        property bool clockWeekday: false
        property bool clockSeconds: false
        // Qt date/time formats; "" = the automatic format from the toggles above.
        property string barFormat: ""
        property string lockTimeFormat: ""
        property string lockDateFormat: ""
        property bool batteryPercent: false
        // Monitor name (e.g. "DP-1") for the top bar; "" = every monitor.
        property string barScreen: ""
        // Umbriel blur behind the bar, dock, calendar, notifications and OSD.
        property bool blur: false
        // Opacity of those surfaces while blur is on (0.3–1).
        property real blurOpacity: 0.7
        property bool dockAutohide: true
        property string dockIconSize: "default" // small | default | large
        property string nightFrom: "20:00"
        property string nightTo: "06:00"
        property int nightTemp: 4000
        // "" = ~/Pictures/Wallpapers
        property string wallpaperDir: ""
    }

    property FileView file: FileView {
        path: root.stateDir + "/settings.json"
        printErrors: false
        adapter: root.options
        // Blocking so components start with the saved values, not the defaults.
        blockLoading: true
        // Hand edits to the JSON apply live.
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                Quickshell.execDetached(["mkdir", "-p", root.stateDir])
                writeAdapter()
            }
        }
    }

    // ---- Clock formats (top bar, lock screen) ----
    readonly property string defaultBarFormat: (options.clockWeekday ? "ddd " : "") + "MMM d  "
        + (options.clock24h ? "HH:mm" : "h:mm") + (options.clockSeconds ? ":ss" : "") + (options.clock24h ? "" : " AP")
    // Qt only uses a 12-hour "h" when the format has AP.
    readonly property string defaultLockTimeFormat: options.clock24h ? "HH:mm" : "h:mm AP"
    readonly property string defaultLockDateFormat: "dddd, MMMM d"
    readonly property string barFormat: options.barFormat || defaultBarFormat
    readonly property string lockTimeFormat: options.lockTimeFormat || defaultLockTimeFormat
    readonly property string lockDateFormat: options.lockDateFormat || defaultLockDateFormat

    // ---- Settings window ----
    property bool windowOpen: false
    property string page: "datetime"
    function openWindow(page) {
        if (page) root.page = page
        root.windowOpen = true
    }

    // ---- Blur strength: `radius` under [appearance.blur] in umbriel's config ----
    // Read from and written to umbriel's file (it reloads live), so it stays the
    // one place the value lives. Global: also applies to window blur.
    readonly property string umbrielConfig: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/umbriel/config.toml"
    property int blurRadius: -1 // -1 until read
    function readBlurRadius() { blurRead.running = true }
    function setBlurRadius(r) { root.blurRadius = r; blurWrite.restart() }

    readonly property string blurAwk: "/^\\[/ { if (sec && !done) { print \"radius = \" r; done = 1 }"
        + " sec = ($0 ~ /^\\[appearance\\.blur\\][ \\t]*(#.*)?$/) }"
        + " sec && /^[ \\t]*radius[ \\t]*=/ { if (!done) print \"radius = \" r; done = 1; next }"
        + " { print }"
        + " END { if (!done) { if (!sec) print \"\\n[appearance.blur]\"; print \"radius = \" r } }"

    // No radius line means umbriel's default, 5.
    property Process blurRead: Process {
        command: ["awk", "/^\\[/ { sec = ($0 ~ /^\\[appearance\\.blur\\][ \\t]*(#.*)?$/) }"
            + " sec && /^[ \\t]*radius[ \\t]*=/ { sub(/^[^=]*=[ \\t]*/, \"\"); print $1 + 0; found = 1 }"
            + " END { if (!found) print 5 }", root.umbrielConfig]
        stdout: StdioCollector { onStreamFinished: { var n = parseInt(text); if (!isNaN(n)) root.blurRadius = n } }
    }
    // Waits for the slider to settle: umbriel reloads on every write.
    property Timer blurWrite: Timer {
        interval: 400
        onTriggered: Quickshell.execDetached(["sh", "-c",
            // Rewrite in place (keeps the inode umbriel watches).
            "awk -v r=\"$1\" \"$2\" \"$3\" > \"$3.tmp\" && cat \"$3.tmp\" > \"$3\"; rm -f \"$3.tmp\"",
            "sh", String(root.blurRadius), root.blurAwk, root.umbrielConfig])
    }

    // ---- Night light (wlsunset) ----
    function nightLightCommand() {
        var o = root.options
        // wlsunset needs the day temperature above the night one.
        return ["wlsunset", "-s", o.nightFrom, "-S", o.nightTo,
                "-t", String(o.nightTemp), "-T", String(Math.max(6500, o.nightTemp + 100))]
    }
    // Restart wlsunset with the new schedule, only if it's running. The
    // pause lets the old instance release the gamma control first.
    function restartNightLight() {
        Quickshell.execDetached(["sh", "-c", "pkill -x wlsunset && sleep 0.3 && exec \"$@\"", "sh"]
            .concat(root.nightLightCommand()))
    }
}
