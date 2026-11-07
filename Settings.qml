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
        property bool batteryPercent: false
        // Monitor name (e.g. "DP-1") for the top bar; "" = every monitor.
        property string barScreen: ""
        // Blurred wallpaper behind the bar and dock.
        property bool blur: false
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

    // ---- Settings window ----
    property bool windowOpen: false
    property string page: "datetime"
    function openWindow(page) {
        if (page) root.page = page
        root.windowOpen = true
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
