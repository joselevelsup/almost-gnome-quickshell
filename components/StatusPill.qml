import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import ".."

// System status icons on the right of the bar (network, bluetooth,
// volume, battery) that open Quick Settings, like GNOME Shell's
// top-right status area.
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

    // Like GNOME, ethernet takes the network icon's place while connected.
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)

    // Bluetooth shows in the pill only while a device is connected.
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btConnected: {
        if (!pill.btAdapter || !pill.btAdapter.devices) return false
        var devs = pill.btAdapter.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected) return true
        return false
    }

    SymbolicIcon {
        name: pill.wired ? "network-wired-symbolic"
            : !Networking.wifiEnabled ? "network-wireless-disabled-symbolic"
            : (pill.wifiDevice && pill.wifiDevice.connected) ? "network-wireless-symbolic" : "network-wireless-signal-none-symbolic"
    }
    SymbolicIcon {
        visible: pill.btConnected
        name: "bluetooth-active-symbolic"
    }
    SymbolicIcon {
        name: !pill.audio ? "audio-volume-muted-symbolic"
            : pill.audio.muted ? "audio-volume-muted-symbolic"
            : pill.audio.volume > 0.5 ? "audio-volume-high-symbolic"
            : pill.audio.volume > 0 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic"
    }
    BatteryIcon {
        visible: pill.hasBattery
        percentage: pill.hasBattery ? pill.battery.percentage : 1
        charging: pill.charging
    }
    Text {
        visible: pill.hasBattery && Settings.options.batteryPercent
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        text: Math.round(pill.battery.percentage * 100) + "%"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    onClicked: PopupManager.open("quicksettings")
}
