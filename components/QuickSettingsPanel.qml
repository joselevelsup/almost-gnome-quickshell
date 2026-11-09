import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."

// GNOME 50 style Quick Settings: system row on top (battery, screenshot,
// settings, lock, power), volume and brightness sliders and a grid of
// pill-shaped quick toggles.
PopupCard {
    id: popup
    popupName: "quicksettings"
    align: "right"
    cardWidth: 400

    property bool powerMenuOpen: false
    property bool outputsOpen: false
    onVisibleChanged: {
        if (popup.visible) probe.running = true
        else { popup.powerMenuOpen = false; popup.outputsOpen = false; popup.netOpen = "" }
    }

    function run(cmd) { PopupManager.close(); Quickshell.execDetached(cmd) }

    // Expanded settings row under the Wi-Fi/Bluetooth toggles: "wifi", "bt" or "".
    property string netOpen: ""
    // What the card shows; kept while it collapses so the text doesn't vanish.
    property string netShown: "wifi"
    onNetOpenChanged: if (popup.netOpen) popup.netShown = popup.netOpen
    // Opens a TUI in a floating alacritty (umbriel rule on ^qs-tui-), or
    // closes it if already open. cls/prog go in as $1/$2 so this sh's own
    // command line never matches the pkill pattern. ~/.local/bin isn't on
    // umbriel's PATH (bluetui lives there).
    function toggleTui(cls, prog) {
        popup.run(["sh", "-c", "pkill -f \"class $1\" || umbriel msg spawn "
            + "\"PATH=\\$HOME/.local/bin:\\$PATH alacritty --class $1 -e $2\"", "sh", cls, prog])
    }

    // ---- Wi-Fi ----
    property var wifiDevice: null
    property string wifiNetworkName: ""
    function findWifiDevice() {
        popup.wifiNetworkName = ""
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) {
                popup.wifiDevice = devs[i]
                var nets = popup.wifiDevice.networks.values
                for (var j = 0; j < nets.length; j++) {
                    if (nets[j].connected) { popup.wifiNetworkName = nets[j].name; break }
                }
                return
            }
        }
        popup.wifiDevice = null
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: popup.findWifiDevice() }

    // ---- Bluetooth ----
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: popup.btAdapter ? popup.btAdapter.enabled : false
    readonly property string btConnectedName: {
        if (!popup.btAdapter || !popup.btAdapter.devices) return ""
        var devs = popup.btAdapter.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected) return devs[i].name
        return ""
    }

    // ---- Audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: popup.sink ? popup.sink.audio : null
    // Without a tracker Pipewire doesn't keep node properties (volume/mute)
    // live, and the slider wouldn't reflect changes made elsewhere.
    PwObjectTracker { objects: popup.sink ? [popup.sink] : [] }
    // Physical outputs (no app streams), to pick the default.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    function sinkLabel(n) { return n.description || n.nickname || n.name }
    function sinkIcon(n) {
        return /headphone|headset/i.test(popup.sinkLabel(n))
            ? "audio-headphones-symbolic" : "audio-speakers-symbolic"
    }

    // ---- Optional tools ----
    // Night light uses wlsunset and power mode uses power-profiles-daemon.
    // If missing, their controls are shown disabled (not hidden) and say
    // what's missing.
    property bool hasSunset: false
    property bool sunsetOn: false
    property bool hasProfiles: false
    Process {
        id: probe
        command: ["sh", "-c",
            "command -v wlsunset >/dev/null && echo sunset; " +
            "pgrep -x wlsunset >/dev/null && echo sunset-on; " +
            "busctl --system list 2>/dev/null | grep -qE 'net.hadess.PowerProfiles|org.freedesktop.UPower.PowerProfiles' && echo profiles; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n")
                popup.hasSunset = l.indexOf("sunset") !== -1
                popup.sunsetOn = l.indexOf("sunset-on") !== -1
                popup.hasProfiles = l.indexOf("profiles") !== -1
            }
        }
    }
    // Re-read the real state after starting/stopping wlsunset.
    Timer { id: reprobe; interval: 300; onTriggered: probe.running = true }

    // ---- Battery ----
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: popup.battery && popup.battery.isPresent
    readonly property bool charging: popup.hasBattery && popup.battery.state === UPowerDeviceState.Charging

    // ---- Brightness ----
    property real brightness: 0.5
    property bool hasBrightness: false
    function refreshBrightness() { brightnessRead.running = true }
    Process {
        id: brightnessRead
        // Prints the percentage, e.g. "45.00".
        command: ["light", "-G"]
        stdout: StdioCollector {
            onStreamFinished: {
                var pct = parseFloat(text.trim())
                if (!isNaN(pct)) { popup.brightness = pct / 100; popup.hasBrightness = true }
            }
        }
    }
    Component.onCompleted: {
        probe.running = true
        popup.findWifiDevice()
        popup.refreshBrightness()
    }

    // =================================================================
    // System row
    // =================================================================
    RowLayout {
        width: parent.width
        spacing: 6

        Rectangle {
            visible: popup.hasBattery
            implicitHeight: 34
            implicitWidth: batRow.implicitWidth + 24
            radius: height / 2
            color: Theme.cardBg
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 6
                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    percentage: popup.hasBattery ? popup.battery.percentage : 1
                    charging: popup.charging
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.hasBattery ? Math.round(popup.battery.percentage * 100) + "%" : ""
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }
        }

        Item { Layout.fillWidth: true }

        IconButton {
            icon: "applets-screenshooter-symbolic"
            onClicked: PopupManager.open("screenshot")
        }
        IconButton {
            icon: "preferences-system-symbolic"
            onClicked: { PopupManager.close(); Settings.openWindow("") }
        }
        IconButton {
            icon: "system-lock-screen-symbolic"
            onClicked: PopupManager.lockScreen()
        }
        IconButton {
            icon: "system-shutdown-symbolic"
            checked: popup.powerMenuOpen
            onClicked: popup.powerMenuOpen = !popup.powerMenuOpen
        }
    }

    // ---- Power menu (expands below the system row) ----
    Item {
        width: parent.width
        height: popup.powerMenuOpen ? powerCol.implicitHeight : 0
        visible: height > 0
        clip: true
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            id: powerCard
            width: parent.width
            height: powerCol.implicitHeight
            radius: Theme.radius - 2
            color: Theme.cardBg

            Column {
                id: powerCol
                width: parent.width
                topPadding: 4
                bottomPadding: 4
                ActionRow { width: parent.width; icon: "weather-clear-night-symbolic"; label: "Suspend"; onClicked: popup.run(["systemctl", "suspend"]) }
                ActionRow { width: parent.width; icon: "system-reboot-symbolic"; label: "Restart"; onClicked: popup.run(["systemctl", "reboot"]) }
                ActionRow { width: parent.width; icon: "system-log-out-symbolic"; label: "Log Out"; onClicked: popup.run(["umbriel", "msg", "session-quit", "skip-confirmation"]) }
                ActionRow { width: parent.width; icon: "system-shutdown-symbolic"; label: "Power Off"; tint: Theme.danger; onClicked: popup.run(["systemctl", "poweroff"]) }
            }
        }
    }

    // =================================================================
    // Sliders
    // =================================================================
    SliderRow {
        width: parent.width
        muted: !popup.audio || popup.audio.muted
        icon: !popup.audio ? "audio-volume-muted-symbolic"
            : popup.audio.muted ? "audio-volume-muted-symbolic"
            : popup.audio.volume > 0.66 ? "audio-volume-high-symbolic"
            : popup.audio.volume > 0.33 ? "audio-volume-medium-symbolic"
            : popup.audio.volume > 0 ? "audio-volume-low-symbolic" : "audio-volume-muted-symbolic"
        value: popup.audio ? popup.audio.volume : 0
        onValueEdited: v => Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)])
        onIconClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        expandable: popup.sinks.length > 1
        expanded: popup.outputsOpen
        onExpandClicked: popup.outputsOpen = !popup.outputsOpen
    }

    // ---- Audio outputs (expands below the volume slider) ----
    Item {
        width: parent.width
        height: popup.outputsOpen ? outputsCol.implicitHeight : 0
        visible: height > 0
        clip: true
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            width: parent.width
            height: outputsCol.implicitHeight
            radius: Theme.radius - 2
            color: Theme.cardBg

            Column {
                id: outputsCol
                width: parent.width
                topPadding: 4
                bottomPadding: 4
                Repeater {
                    model: popup.sinks
                    delegate: ActionRow {
                        required property var modelData
                        readonly property bool current: popup.sink === modelData
                        width: outputsCol.width
                        icon: current ? "object-select-symbolic" : popup.sinkIcon(modelData)
                        label: popup.sinkLabel(modelData)
                        tint: current ? Theme.accent : Theme.fg
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }
        }
    }
    SliderRow {
        width: parent.width
        visible: popup.hasBrightness
        icon: "display-brightness-symbolic"
        value: popup.brightness
        onValueEdited: v => {
            popup.brightness = v
            Quickshell.execDetached(["light", "-S", String(Math.max(1, Math.round(v * 100)))])
        }
    }

    // =================================================================
    // Quick toggles
    // =================================================================
    GridLayout {
        width: parent.width
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        QuickToggle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: Networking.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-disabled-symbolic"
            label: "Wi-Fi"
            sublabel: !Networking.wifiEnabled ? "Off"
                : (popup.wifiDevice && popup.wifiDevice.connected && popup.wifiNetworkName) ? popup.wifiNetworkName
                : "Disconnected"
            checked: Networking.wifiEnabled
            onToggled: value => Networking.wifiEnabled = value
            expandable: true
            expanded: popup.netOpen === "wifi"
            onExpandClicked: popup.netOpen = expanded ? "" : "wifi"
        }
        QuickToggle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            enabled: popup.btAdapter !== null
            icon: popup.btOn ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            label: "Bluetooth"
            sublabel: !popup.btOn ? "Off" : (popup.btConnectedName || "On")
            checked: popup.btOn
            onToggled: value => { if (popup.btAdapter) popup.btAdapter.enabled = value }
            expandable: true
            expanded: popup.netOpen === "bt"
            onExpandClicked: popup.netOpen = expanded ? "" : "bt"
        }

        // ---- Wi-Fi / Bluetooth settings (expands below their toggles) ----
        Item {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: popup.netOpen ? netCol.implicitHeight : 0
            visible: Layout.preferredHeight > 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                width: parent.width
                height: netCol.implicitHeight
                radius: Theme.radius - 2
                color: Theme.cardBg

                Column {
                    id: netCol
                    width: parent.width
                    topPadding: 4
                    bottomPadding: 4
                    ActionRow {
                        width: parent.width
                        icon: popup.netShown === "bt" ? "bluetooth-active-symbolic" : "network-wireless-symbolic"
                        label: popup.netShown === "bt" ? "Bluetooth Settings…" : "Wi-Fi Settings…"
                        onClicked: popup.netShown === "bt" ? popup.toggleTui("qs-tui-bt", "bluetui")
                                                          : popup.toggleTui("qs-tui-wifi", "nmtui")
                    }
                }
            }
        }
        QuickToggle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: Notifications.dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
            label: "Do Not Disturb"
            sublabel: Notifications.dnd ? "On" : "Off"
            checked: Notifications.dnd
            onToggled: value => Notifications.dnd = value
        }
        QuickToggle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            iconSource: "file://" + Quickshell.shellPath("assets/caffeine-symbolic.svg")
            label: "Caffeine"
            sublabel: Caffeine.enabled ? "Screen stays awake" : "Off"
            checked: Caffeine.enabled
            onToggled: value => Caffeine.enabled = value
        }
        QuickToggle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            enabled: popup.hasSunset
            icon: "night-light-symbolic"
            label: "Night Light"
            sublabel: !popup.hasSunset ? "wlsunset not installed" : popup.sunsetOn ? "On" : "Off"
            checked: popup.sunsetOn
            onToggled: value => {
                Quickshell.execDetached(value ? Settings.nightLightCommand() : ["pkill", "-x", "wlsunset"])
                reprobe.restart()
            }
        }
    }

    // =================================================================
    // Power mode
    // =================================================================
    SectionLabel { text: "Power Mode" }
    SegmentedControl {
        width: parent.width
        enabled: popup.hasProfiles
        opacity: enabled ? 1 : 0.4
        model: {
            var m = [
                { label: "Power Saver", value: String(PowerProfile.PowerSaver) },
                { label: "Balanced", value: String(PowerProfile.Balanced) }
            ]
            // Don't touch PowerProfiles without the daemon: accessing it tries
            // to start it and floods the log with warnings.
            if (popup.hasProfiles && PowerProfiles.hasPerformanceProfile)
                m.push({ label: "Performance", value: String(PowerProfile.Performance) })
            return m
        }
        current: popup.hasProfiles ? String(PowerProfiles.profile) : ""
        onSelected: value => PowerProfiles.profile = parseInt(value)
    }
    Text {
        visible: !popup.hasProfiles
        width: parent.width
        leftPadding: 4
        text: "Requires power-profiles-daemon"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
