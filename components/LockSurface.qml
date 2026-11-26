import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

// One monitor of the lock screen (lock.qml), GNOME 50 style: blurred
// wallpaper with a big clock; a click or key press slides the clock away
// and shows the avatar, name and password field. State is shared through
// `ctx` so every monitor shows the same thing.
WlSessionLockSurface {
    id: surface
    required property var ctx
    color: "#000000"

    // Clock, prompt and status icons only on the laptop screen; the others
    // get just the blurred wallpaper. Falls back to the first screen when
    // the laptop screen is off (lid closed), so the prompt never goes missing.
    readonly property string mainOutput: "eDP-1"
    readonly property bool isMain: Quickshell.screens.some(s => s.name === surface.mainOutput)
        ? surface.screen !== null && surface.screen.name === surface.mainOutput
        : surface.screen === Quickshell.screens[0]

    // Password shown in plain text; back to dots whenever the prompt closes.
    property bool reveal: false
    Connections {
        target: surface.ctx
        function onPromptingChanged() { if (!surface.ctx.prompting) surface.reveal = false }
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifi: Networking.devices.values.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    // MPRIS is plain DBus, so this instance can watch players directly
    // alongside the shell. Whichever player is playing, else the first.
    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
        || Mpris.players.values[0] || null

    // ---- Background ----
    Image {
        id: bg
        anchors.fill: parent
        source: Wallpaper.current ? "file://" + Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 960
        sourceSize.height: 540
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bg
        visible: bg.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
    }
    Rectangle {
        anchors.fill: parent
        // GNOME keeps the blurred wallpaper bright, dimmed only enough for white text.
        color: Theme.withAlpha("#000000", 0.3)
    }

    // ---- Input: one handler for the whole surface, so typing works right away ----
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            var c = surface.ctx
            if (event.key === Qt.Key_Escape) {
                c.buffer = ""
                c.errorText = ""
                c.prompting = false
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (c.prompting) c.submit()
                c.prompting = true
            } else if (event.key === Qt.Key_Backspace) {
                if (!c.busy) c.buffer = c.buffer.slice(0, -1)
                c.prompting = true
            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32
                       && !(event.modifiers & Qt.ControlModifier)) {
                if (!c.busy) c.buffer += event.text
                c.prompting = true
            } else {
                c.prompting = true
            }
            event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: { surface.ctx.prompting = true; keys.forceActiveFocus() }
        }
    }

    // Back to the clock after a while without typing, like GNOME.
    Timer {
        interval: 30000
        running: surface.ctx.prompting && surface.ctx.buffer.length === 0 && !surface.ctx.busy
        onTriggered: { surface.ctx.prompting = false; surface.ctx.errorText = "" }
    }

    // ---- Clock ----
    Column {
        id: clockCol
        visible: surface.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.ctx.prompting ? -height : surface.height * 0.22
        opacity: surface.ctx.prompting ? 0 : 1
        spacing: 4
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Clock.now, Settings.lockTimeFormat)
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 96
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Clock.now, Settings.lockDateFormat)
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
    }
    Text {
        visible: surface.isMain
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        opacity: surface.ctx.prompting ? 0 : 0.8
        Behavior on opacity { NumberAnimation { duration: 200 } }
        text: "Click or press a key to unlock"
        color: "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    // ---- Media controls (GNOME-style, above the unlock hint) ----
    Rectangle {
        visible: surface.isMain && surface.player !== null
            && (surface.player.trackTitle || "").length > 0
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 96 }
        width: 380
        height: 92
        radius: Theme.radius - 2
        color: Theme.withAlpha("#ffffff", 0.12)
        border.width: 1
        border.color: Theme.withAlpha("#ffffff", 0.25)

        // Only the buttons take clicks; the card itself stays click-through
        // so typing and clicking elsewhere still reach the unlock prompt.
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // ---- Cover art ----
            ClippingRectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: Theme.radius - 6
                color: "transparent"

                Image {
                    id: art
                    anchors.fill: parent
                    source: surface.player ? surface.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 128
                    sourceSize.height: 128
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                SymbolicIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    name: "audio-x-generic-symbolic"
                    size: 24
                    tint: Theme.withAlpha("#ffffff", 0.6)
                }
            }

            // ---- Text + controls ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: surface.player ? (surface.player.identity || "Player") : ""
                    color: Theme.withAlpha("#ffffff", 0.6)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: surface.player ? (surface.player.trackTitle || "Unknown title") : ""
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: surface.player ? (surface.player.trackArtist || "") : ""
                    color: Theme.withAlpha("#ffffff", 0.8)
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    IconButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        flat: true
                        icon: "media-skip-backward-symbolic"
                        tint: Theme.withAlpha("#ffffff", 0.85)
                        enabled: surface.player && surface.player.canGoPrevious
                        onClicked: surface.player.previous()
                    }
                    IconButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        flat: true
                        icon: surface.player && surface.player.isPlaying
                            ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                        tint: Theme.withAlpha("#ffffff", 0.85)
                        enabled: surface.player && surface.player.canTogglePlaying
                        onClicked: surface.player.togglePlaying()
                    }
                    IconButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        flat: true
                        icon: "media-skip-forward-symbolic"
                        tint: Theme.withAlpha("#ffffff", 0.85)
                        enabled: surface.player && surface.player.canGoNext
                        onClicked: surface.player.next()
                    }
                }
            }
        }
    }

    // ---- Status icons (top right, like GNOME's lock screen panel) ----
    Row {
        visible: surface.isMain
        anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 14 }
        spacing: 10
        SymbolicIcon {
            visible: surface.wired || surface.wifi || !Networking.wifiEnabled
            name: surface.wired ? "network-wired-symbolic"
                : surface.wifi ? "network-wireless-symbolic" : "network-wireless-disabled-symbolic"
        }
        SymbolicIcon {
            visible: surface.audio !== null
            name: !surface.audio || surface.audio.muted ? "audio-volume-muted-symbolic"
                : surface.audio.volume > 0.5 ? "audio-volume-high-symbolic"
                : surface.audio.volume > 0 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic"
        }
        BatteryIcon {
            visible: surface.battery && surface.battery.isPresent
            percentage: visible ? surface.battery.percentage : 1
            charging: visible && surface.battery.state === UPowerDeviceState.Charging
        }
    }

    // ---- Notification toasts (forwarded over IPC by the shell) ----
    Column {
        visible: surface.isMain
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 12 }
        spacing: 8

        // Deliberately no entrance/exit animations: the Repeater over the
        // ctx.toasts array rebuilds the survivors on every dismissal, which
        // would replay their entrance.
        Repeater {
            model: surface.ctx.toasts
            delegate: NotificationRow {
                id: lockToast
                required property var modelData
                width: 500
                appName: modelData.appName
                summary: modelData.summary
                body: modelData.body || ""
                appIcon: modelData.appIcon || ""
                image: ""
                time: null
                elevated: true

                onDismissRequested: surface.ctx.dismissToast(lockToast.modelData)

                // Auto-dismiss pauses while hovered, like the shell's toasts.
                HoverHandler { id: toastHover }

                Timer {
                    interval: 6000
                    running: !toastHover.hovered
                    onTriggered: surface.ctx.dismissToast(lockToast.modelData)
                }
            }
        }
    }

    // ---- Unlock prompt ----
    Column {
        id: prompt
        anchors.horizontalCenter: parent.horizontalCenter
        // Centered, nudged a little above the middle like GNOME's unlock dialog.
        y: (surface.height - height) / 2 - surface.height * 0.04 + (surface.ctx.prompting ? 0 : 40)
        opacity: surface.ctx.prompting ? 1 : 0
        visible: surface.isMain && opacity > 0
        spacing: 16
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Avatar: AccountsService icon, then ~/.face, then the symbolic fallback.
        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 144
            height: 144
            radius: 72
            color: Theme.cardBg
            clip: true

            readonly property var sources: [
                "file:///var/lib/AccountsService/icons/" + surface.ctx.user,
                "file://" + Quickshell.env("HOME") + "/.face"
            ]
            property int attempt: 0

            Image {
                id: face
                anchors.fill: parent
                source: avatar.attempt < avatar.sources.length ? avatar.sources[avatar.attempt] : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 288
                sourceSize.height: 288
                visible: false
                onStatusChanged: if (status === Image.Error) avatar.attempt++
            }
            Rectangle {
                id: faceMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: faceMask
            }
            SymbolicIcon {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                name: "avatar-default-symbolic"
                size: 72
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface.ctx.realName || surface.ctx.user
            // Extra room between the name and the password field.
            height: implicitHeight + 10
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        // Password field (dots only; the text lives in ctx.buffer).
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 38
            radius: 9
            color: Theme.withAlpha("#ffffff", 0.18)
            border.width: 2
            border.color: surface.ctx.errorText ? Theme.danger : Theme.accent
            opacity: surface.ctx.busy ? 0.6 : 1

            Text {
                anchors { left: parent.left; right: eye.left; leftMargin: 12; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: surface.ctx.buffer.length === 0 ? (surface.ctx.busy ? "Checking…" : "Password")
                    : surface.reveal ? surface.ctx.buffer : "●".repeat(surface.ctx.buffer.length)
                color: surface.ctx.buffer.length > 0 ? "#ffffff" : Theme.withAlpha("#ffffff", 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.letterSpacing: surface.ctx.buffer.length > 0 && !surface.reveal ? 2 : 0
                elide: Text.ElideLeft
            }

            // Show/hide the password, like GNOME's peek icon.
            Item {
                id: eye
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 26
                height: 26
                SymbolicIcon {
                    anchors.centerIn: parent
                    name: surface.reveal ? "view-conceal-symbolic" : "view-reveal-symbolic"
                    size: 16
                    tint: Theme.withAlpha("#ffffff", eyeMouse.containsMouse ? 1 : 0.75)
                }
                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { surface.reveal = !surface.reveal; keys.forceActiveFocus() }
                }
            }

            // Shake on a failed attempt.
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }
            Connections {
                target: surface.ctx
                function onFailuresChanged() { shake.restart() }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text.length > 0
            text: surface.ctx.errorText
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }
    }
}
