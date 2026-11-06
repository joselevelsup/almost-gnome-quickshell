pragma Singleton
import Quickshell.Io
import QtQuick

// Current time in the timezone chosen in Settings ("" = system). QML's
// JavaScript has no time zone support, so `date` reports the zone's UTC
// offset and `now` is the local time shifted by the difference: read it
// with the usual getHours()/getDate()/… accessors.
QtObject {
    id: clock

    property var now: new Date()
    // Minutes east of UTC for Settings.options.timezone.
    property int zoneOffset: 0

    function parseOffset(s) {
        var m = /^([+-])(\d\d)(\d\d)$/.exec(String(s).trim())
        if (!m) return null
        var v = parseInt(m[2], 10) * 60 + parseInt(m[3], 10)
        return m[1] === "-" ? -v : v
    }
    function shifted(d, offset) {
        if (!Settings.options.timezone) return d
        return new Date(d.getTime() + (offset + d.getTimezoneOffset()) * 60000)
    }
    function tick() { clock.now = clock.shifted(new Date(), clock.zoneOffset) }

    property Timer ticker: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.tick()
    }
    // Re-read the offset now and then so daylight saving changes are picked up.
    property Timer offsetTimer: Timer {
        interval: 10 * 60 * 1000
        running: Settings.options.timezone !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: offsetProc.running = true
    }
    property Process offsetProc: Process {
        command: ["env", "TZ=" + Settings.options.timezone, "date", "+%z"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = clock.parseOffset(text)
                if (o !== null) { clock.zoneOffset = o; clock.tick() }
            }
        }
    }
    property Connections tzWatch: Connections {
        target: Settings.options
        function onTimezoneChanged() { clock.tick(); offsetProc.running = true }
    }

    Component.onCompleted: {
        console.assert(parseOffset("+0530") === 330 && parseOffset("-0800") === -480
            && parseOffset("garbage") === null, "Clock.parseOffset self-check failed")
        tick()
    }
}
