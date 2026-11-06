import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import ".."

// One monitor of the lock screen (lock.qml), GNOME 50 style: blurred
// wallpaper with a big clock; a click or key press slides the clock away
// and shows the avatar, name and password field. State is shared through
// `ctx` so every monitor shows the same thing.
WlSessionLockSurface {
    id: surface
    required property var ctx
    color: "#000000"

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
        color: Theme.withAlpha("#000000", surface.ctx.prompting ? 0.6 : 0.4)
        Behavior on color { ColorAnimation { duration: 200 } }
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
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.ctx.prompting ? -height : surface.height * 0.22
        opacity: surface.ctx.prompting ? 0 : 1
        spacing: 4
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Clock.now, Settings.options.clock24h ? "HH:mm" : "h:mm")
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 96
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Clock.now, "dddd, MMMM d")
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        opacity: surface.ctx.prompting ? 0 : 0.8
        Behavior on opacity { NumberAnimation { duration: 200 } }
        text: "Click or press a key to unlock"
        color: "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    // ---- Unlock prompt ----
    Column {
        id: prompt
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.height * 0.3 + (surface.ctx.prompting ? 0 : 40)
        opacity: surface.ctx.prompting ? 1 : 0
        visible: opacity > 0
        spacing: 16
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Avatar: AccountsService icon, then ~/.face, then the symbolic fallback.
        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 128
            height: 128
            radius: 64
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
                sourceSize.width: 256
                sourceSize.height: 256
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
                size: 64
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface.ctx.realName || surface.ctx.user
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Bold
        }

        // Password field (dots only; the text lives in ctx.buffer).
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 40
            radius: height / 2
            color: Theme.withAlpha("#ffffff", 0.14)
            border.width: 2
            border.color: surface.ctx.errorText ? Theme.danger : Theme.accent
            opacity: surface.ctx.busy ? 0.6 : 1

            Text {
                anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; verticalCenter: parent.verticalCenter }
                text: surface.ctx.buffer.length > 0 ? "●".repeat(surface.ctx.buffer.length)
                    : surface.ctx.busy ? "Checking…" : "Password"
                color: surface.ctx.buffer.length > 0 ? "#ffffff" : Theme.withAlpha("#ffffff", 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: surface.ctx.buffer.length > 0 ? 12 : 14
                font.letterSpacing: surface.ctx.buffer.length > 0 ? 2 : 0
                elide: Text.ElideLeft
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
            width: 300
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text.length > 0
            text: surface.ctx.errorText
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
