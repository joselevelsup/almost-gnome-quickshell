import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import ".."

// System status icons on the right of the bar (network, volume, battery)
// that open Quick Settings, like GNOME Shell's top-right status area.
BarButton {
    id: pill
    active: PopupManager.current === "quicksettings"
    spacing: 8

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: pill.battery && pill.battery.isPresent
    readonly property bool charging: pill.hasBattery && pill.battery.state === UPowerDeviceState.Charging

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    property var wifiDevice: null
    function findWifiDevice() {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) { pill.wifiDevice = devs[i]; return }
        }
        pill.wifiDevice = null
    }
    Component.onCompleted: pill.findWifiDevice()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: pill.findWifiDevice() }

    function batteryIcon() {
        if (!pill.hasBattery) return ""
        var pct = pill.battery.percentage * 100
        var step = Math.min(100, Math.max(0, Math.round(pct / 10) * 10))
        if (step === 100 && pill.charging) return "battery-level-100-charged-symbolic"
        return "battery-level-" + step + (pill.charging ? "-charging" : "") + "-symbolic"
    }

    SymbolicIcon {
        name: !Networking.wifiEnabled ? "network-wireless-disabled-symbolic"
            : (pill.wifiDevice && pill.wifiDevice.connected) ? "network-wireless-symbolic" : "network-wireless-signal-none-symbolic"
    }
    SymbolicIcon {
        name: !pill.audio ? "audio-volume-muted-symbolic"
            : pill.audio.muted ? "audio-volume-muted-symbolic"
            : pill.audio.volume > 0.5 ? "audio-volume-high-symbolic"
            : pill.audio.volume > 0 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic"
    }
    SymbolicIcon {
        visible: pill.hasBattery
        name: pill.batteryIcon()
    }
    Text {
        visible: pill.hasBattery && Settings.options.batteryPercent
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        text: Math.round(pill.battery.percentage * 100) + "%"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    onClicked: PopupManager.open("quicksettings")
}
