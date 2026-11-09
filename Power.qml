pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick

// GNOME-style power saving: dim, blank, lock and suspend when idle, lock
// before any sleep, and Power Saver on low battery. The settings are
// GNOME's own (gsettings), so GNOME Settings → Power and our Settings →
// Power edit the same values. Idle timers respect inhibitors (Caffeine,
// idle-inhibit from apps). Created at startup from shell.qml.
// A Singleton (not QtObject) whose monitors are children: Quickshell only
// activates IdleMonitors that get its reload hook, which Singleton passes
// to children. Each monitor sits in a Variants keyed on its timeout, so it
// is recreated when the timeout changes: an IdleMonitor keeps its first
// timeout (Quickshell 0.3), and these start before gsettings are read.
Singleton {
    id: power

    readonly property string sessionSchema: "org.gnome.desktop.session"
    readonly property string lockSchema: "org.gnome.desktop.screensaver"
    readonly property string powerSchema: "org.gnome.settings-daemon.plugins.power"

    // ---- GNOME settings (times in seconds; 0 = never) ----
    property int idleDelay: 300
    property bool idleDim: true
    property bool lockEnabled: true
    property int lockDelay: 0
    property int sleepBattery: 900
    property string sleepBatteryType: "suspend"
    property int sleepAc: 900
    property string sleepAcType: "suspend"
    property bool lowBatterySaver: true

    function set(schema, key, value) {
        Quickshell.execDetached(["gsettings", "set", schema, key, String(value)])
    }

    // gsettings prints e.g. "uint32 300", "true", "'suspend'".
    function clean(raw) { return raw.trim().replace(/^u?int32 /, "").replace(/^'(.*)'$/, "$1") }
    function apply(key, raw) {
        var v = power.clean(raw)
        switch (key) {
        case "idle-delay": power.idleDelay = parseInt(v); break
        case "idle-dim": power.idleDim = v === "true"; break
        case "lock-enabled": power.lockEnabled = v === "true"; break
        case "lock-delay": power.lockDelay = parseInt(v); break
        case "sleep-inactive-battery-timeout": power.sleepBattery = parseInt(v); break
        case "sleep-inactive-battery-type": power.sleepBatteryType = v; break
        case "sleep-inactive-ac-timeout": power.sleepAc = parseInt(v); break
        case "sleep-inactive-ac-type": power.sleepAcType = v; break
        case "power-saver-profile-on-low-battery": power.lowBatterySaver = v === "true"; break
        }
    }

    property Process readAll: Process {
        running: true
        command: ["sh", "-c", "for s in \"$@\"; do gsettings list-recursively \"$s\"; done", "sh",
                  power.sessionSchema, power.lockSchema, power.powerSchema]
        // "schema key value"
        stdout: SplitParser {
            onRead: line => {
                var m = /^\S+ (\S+) (.*)$/.exec(line)
                if (m) power.apply(m[1], m[2])
            }
        }
    }
    component Watch: Process {
        property string schema
        running: true
        command: ["gsettings", "monitor", schema]
        // "key: value"
        stdout: SplitParser {
            onRead: line => {
                var i = line.indexOf(": ")
                if (i > 0) power.apply(line.slice(0, i), line.slice(i + 2))
            }
        }
    }
    property Process watchSession: Watch { schema: power.sessionSchema }
    property Process watchLock: Watch { schema: power.lockSchema }
    property Process watchPower: Watch { schema: power.powerSchema }

    // ---- Dim (30 s before blank) ----
    readonly property string dimFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-dim"
    function dim() {
        // Remember the level, then drop to 30% of it.
        Quickshell.execDetached(["sh", "-c", "[ -f \"$1\" ] && exit; c=$(light -G) && echo \"$c\" > \"$1\" && " +
            "light -S \"$(awk -v c=\"$c\" 'BEGIN { v = c * 0.3; print (v < 1 ? 1 : v) }')\"", "sh", power.dimFile])
    }
    function undim() {
        Quickshell.execDetached(["sh", "-c", "[ -f \"$1\" ] && light -S \"$(cat \"$1\")\"; rm -f \"$1\"", "sh", power.dimFile])
    }
    Variants {
        model: power.idleDim && power.idleDelay > 0 ? [Math.max(5, power.idleDelay - 30)] : []
        IdleMonitor {
            required property real modelData
            timeout: modelData
            onIsIdleChanged: isIdle ? power.dim() : power.undim()
        }
    }

    // ---- Blank, then lock ----
    Variants {
        model: power.idleDelay > 0 ? [power.idleDelay] : []
        IdleMonitor {
            required property real modelData
            timeout: modelData
            onIsIdleChanged: {
                if (isIdle) {
                    Umbriel.msg(["dpms-off"])
                    if (power.lockEnabled) power.lockTimer.restart()
                } else {
                    power.lockTimer.stop()
                    Umbriel.msg(["dpms-on"])
                    power.undim()
                }
            }
        }
    }
    property Timer lockTimer: Timer {
        interval: Math.max(1, power.lockDelay) * 1000
        onTriggered: power.lock()
    }

    // Lock unless the lock screen (its own qs instance) is already up.
    function lock() { lockCheck.running = true }
    property Process lockCheck: Process {
        command: ["pgrep", "-f", "lock\\.qml"]
        onExited: code => { if (code !== 0) PopupManager.lockScreen() }
    }

    // ---- Automatic suspend ----
    readonly property bool onBattery: UPower.onBattery
    readonly property int sleepDelay: power.onBattery ? power.sleepBattery : power.sleepAc
    readonly property string sleepType: power.onBattery ? power.sleepBatteryType : power.sleepAcType
    Variants {
        model: power.sleepDelay > 0 && (power.sleepType === "suspend" || power.sleepType === "hibernate")
            ? [Math.max(60, power.sleepDelay)] : []
        IdleMonitor {
            required property real modelData
            timeout: modelData
            onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", power.sleepType])
        }
    }

    // ---- Lock before sleep (lid, menu, idle) ----
    // A delay inhibitor gives the lock screen a moment to draw before the
    // system sleeps, so resume never shows the unlocked desktop.
    property Process sleepInhibitor: Process {
        running: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell",
                  "--why=Lock the screen before sleep", "sleep", "infinity"]
    }
    property Timer releaseInhibitor: Timer {
        interval: 1000
        onTriggered: power.sleepInhibitor.running = false
    }
    property Process sleepWatch: Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep (true") !== -1) {
                    power.lock()
                    power.releaseInhibitor.restart()
                } else if (line.indexOf("PrepareForSleep (false") !== -1) {
                    power.sleepInhibitor.running = true
                }
            }
        }
    }

    // ---- Power Saver on low battery (below 20%, until plugged in) ----
    readonly property bool lowBattery: power.lowBatterySaver && power.onBattery
        && UPower.displayDevice.isPresent && UPower.displayDevice.percentage < 0.2
    property int savedProfile: -1
    onLowBatteryChanged: {
        if (power.lowBattery && PowerProfiles.profile !== PowerProfile.PowerSaver) {
            power.savedProfile = PowerProfiles.profile
            PowerProfiles.profile = PowerProfile.PowerSaver
        } else if (!power.lowBattery && power.savedProfile !== -1) {
            PowerProfiles.profile = power.savedProfile
            power.savedProfile = -1
        }
    }

    // ---- Low battery ping (COSMIC style) ----
    // 1 = low (≤15%, one ping), 2 = critical (≤5%, ping every 2 min until plugged in).
    readonly property int batteryAlert: !power.onBattery || !UPower.displayDevice.isPresent ? 0
        : UPower.displayDevice.percentage <= 0.05 ? 2
        : UPower.displayDevice.percentage <= 0.15 ? 1 : 0
    function ping() { Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/bell.oga"]) }
    onBatteryAlertChanged: if (power.batteryAlert > 0) power.ping()
    property Timer criticalPing: Timer {
        interval: 120000
        repeat: true
        running: power.batteryAlert === 2
        onTriggered: power.ping()
    }

    Component.onCompleted: {
        console.assert(power.clean("uint32 300") === "300" && power.clean("'suspend'") === "suspend"
            && power.clean("true") === "true", "Power.clean self-check failed")
    }
}
