import Quickshell.Io
import QtQuick
import ".."

// CPU and RAM usage in the top bar, read from /proc every 2 s. Click to
// open GNOME System Monitor.
BarButton {
    id: mon
    spacing: 12

    property real cpu: 0      // 0..1
    property real ramUsed: 0  // GiB
    property var prev: null   // last { busy, total } CPU jiffies

    // "cpu  user nice system idle iowait irq softirq steal ..." → { busy, total }
    function parseCpu(line) {
        var f = line.trim().split(/\s+/).slice(1, 9).map(Number)
        var idle = f[3] + f[4]
        var total = f.reduce((a, b) => a + b, 0)
        return { busy: total - idle, total: total }
    }
    // Used = MemTotal - MemAvailable, like GNOME System Monitor. kB → GiB.
    function parseRam(text) {
        var total = /MemTotal:\s+(\d+)/.exec(text)
        var avail = /MemAvailable:\s+(\d+)/.exec(text)
        return total && avail ? (total[1] - avail[1]) / 1048576 : 0
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Process {
        id: proc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var now = mon.parseCpu(text.split("\n")[0])
                if (mon.prev && now.total > mon.prev.total)
                    mon.cpu = (now.busy - mon.prev.busy) / (now.total - mon.prev.total)
                mon.prev = now
                mon.ramUsed = mon.parseRam(text)
            }
        }
    }

    Component.onCompleted: {
        var c = parseCpu("cpu  100 0 50 800 50 0 0 0 0 0")
        console.assert(c.busy === 150 && c.total === 1000, "SystemMonitor.parseCpu self-check failed")
        console.assert(parseRam("MemTotal: 2097152 kB\nMemAvailable: 1048576 kB") === 1,
            "SystemMonitor.parseRam self-check failed")
    }

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        text: "CPU " + Math.round(mon.cpu * 100) + "%"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }
    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        text: "RAM " + mon.ramUsed.toFixed(1) + " GB"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    // Through umbriel so the app isn't a child of the shell (see AppLauncher.qml).
    onClicked: AppLauncher.spawn(["gnome-system-monitor"])
}
