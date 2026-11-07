import Quickshell
import Quickshell.I3
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import ".."

// The shell's settings, as a normal app window like GNOME Settings: pages
// in a sidebar, rows on the right. Opens from the gear button in Quick
// Settings or over IPC (`qs ipc call settings open`). Values live in
// Settings.qml and are saved as they change.
FloatingWindow {
    id: win
    title: "Settings"
    visible: Settings.windowOpen
    implicitWidth: 820
    implicitHeight: 580
    minimumSize: Qt.size(680, 440)
    color: "#222226"

    onClosed: Settings.windowOpen = false
    // Sway would tile it; float and center it like a GNOME app window.
    onVisibleChanged: if (visible) {
        floatTimer.restart()
        if (win.zones.length === 0) zoneProc.running = true
    }
    Timer {
        id: floatTimer
        interval: 50
        onTriggered: I3.dispatch("[pid=" + Quickshell.processId + " title=\"^Settings$\"] floating enable, resize set "
            + win.implicitWidth + " " + win.implicitHeight + ", move position center")
    }

    readonly property var o: Settings.options
    readonly property var pages: [
        { id: "datetime", label: "Date & Time", icon: "preferences-system-time-symbolic" },
        { id: "topbar", label: "Top Bar", icon: "computer-symbolic" },
        { id: "appearance", label: "Appearance", icon: "color-select-symbolic" },
        { id: "background", label: "Background", icon: "preferences-desktop-wallpaper-symbolic" },
        { id: "dock", label: "Dock", icon: "view-app-grid-symbolic" },
        { id: "nightlight", label: "Night Light", icon: "night-light-symbolic" },
        { id: "power", label: "Power", icon: "power-profile-balanced-symbolic" }
    ]
    readonly property var current: pages.find(p => p.id === Settings.page) || pages[0]

    // ---- Timezones (read once, on first open) ----
    property var zones: []
    property string zoneQuery: ""
    readonly property var zoneResults: {
        var q = win.zoneQuery.trim().toLowerCase().replace(/ /g, "_")
        var list = q ? win.zones.filter(z => z.toLowerCase().indexOf(q) !== -1) : win.zones
        return [""].concat(list)
    }
    Process {
        id: zoneProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: win.zones = text.split("\n").filter(z => z.length > 0)
        }
    }

    property RegularExpressionValidator timeValidator: RegularExpressionValidator {
        regularExpression: /^([01]\d|2[0-3]):[0-5]\d$/
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Sidebar ----
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            color: Theme.popupBg

            Column {
                anchors { fill: parent; margins: 8 }
                spacing: 2

                Text {
                    width: parent.width
                    height: 44
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "Settings"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Repeater {
                    model: win.pages
                    delegate: Rectangle {
                        id: navItem
                        required property var modelData
                        readonly property bool selected: win.current.id === modelData.id
                        width: parent.width
                        height: 40
                        radius: Theme.radius - 8
                        color: selected ? Theme.withAlpha("#ffffff", 0.12)
                            : navMouse.containsMouse ? Theme.withAlpha("#ffffff", 0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            SymbolicIcon { anchors.verticalCenter: parent.verticalCenter; name: navItem.modelData.icon }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: navItem.modelData.label
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.page = navItem.modelData.id
                        }
                    }
                }
            }
        }

        // ---- Page ----
        Flickable {
            id: pageFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: page.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page
                x: Math.max(24, (pageFlick.width - width) / 2)
                y: 24
                width: Math.min(560, pageFlick.width - 48)
                spacing: 8

                Text {
                    text: win.current.label
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    bottomPadding: 8
                }

                // ================= Date & Time =================
                Column {
                    visible: win.current.id === "datetime"
                    width: parent.width
                    spacing: 8

                    SettingsRow {
                        width: parent.width
                        title: "24-hour clock"
                        ToggleSwitch { checked: win.o.clock24h; onToggled: v => win.o.clock24h = v }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Show weekday"
                        ToggleSwitch { checked: win.o.clockWeekday; onToggled: v => win.o.clockWeekday = v }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Show seconds"
                        ToggleSwitch { checked: win.o.clockSeconds; onToggled: v => win.o.clockSeconds = v }
                    }

                    SectionLabel { text: "Timezone"; topPadding: 12 }
                    Text {
                        width: parent.width
                        leftPadding: 4
                        wrapMode: Text.WordWrap
                        text: "Only changes the top bar clock and calendar. The system timezone stays as it is."
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    TextField {
                        width: parent.width
                        placeholder: "Search timezones"
                        onEdited: t => win.zoneQuery = t
                    }
                    Rectangle {
                        width: parent.width
                        height: 260
                        radius: Theme.radius - 6
                        color: Theme.cardBg
                        clip: true

                        ListView {
                            id: zoneList
                            anchors { fill: parent; margins: 4 }
                            model: win.zoneResults
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                id: zoneItem
                                required property string modelData
                                readonly property bool selected: win.o.timezone === modelData
                                width: zoneList.width
                                height: 34
                                radius: Theme.radius - 10
                                color: zoneMouse.containsMouse ? Theme.hoverBg : "transparent"

                                Text {
                                    anchors { left: parent.left; leftMargin: 10; right: check.left; verticalCenter: parent.verticalCenter }
                                    text: zoneItem.modelData === "" ? "System default" : zoneItem.modelData.replace(/_/g, " ")
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: zoneItem.selected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                                SymbolicIcon {
                                    id: check
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    visible: zoneItem.selected
                                    name: "object-select-symbolic"
                                    tint: Theme.accent
                                }
                                MouseArea {
                                    id: zoneMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.o.timezone = zoneItem.modelData
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: win.zones.length === 0 && !zoneProc.running
                            text: "Couldn't list timezones (timedatectl)"
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // ================= Top Bar =================
                Column {
                    visible: win.current.id === "topbar"
                    width: parent.width
                    spacing: 8

                    SettingsRow {
                        width: parent.width
                        title: "Show battery percentage"
                        ToggleSwitch { checked: win.o.batteryPercent; onToggled: v => win.o.batteryPercent = v }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Show on"
                        subtitle: "The dock and popups follow the top bar"
                        SegmentedControl {
                            width: 260
                            model: [{ label: "All", value: "" }]
                                .concat(Quickshell.screens.map(s => ({ label: s.name, value: s.name })))
                            current: win.o.barScreen
                            onSelected: v => win.o.barScreen = v
                        }
                    }
                }

                // ================= Appearance =================
                Column {
                    visible: win.current.id === "appearance"
                    width: parent.width
                    spacing: 8

                    // Title above the swatches: nine of them don't fit beside it.
                    Rectangle {
                        width: parent.width
                        height: accentCol.implicitHeight + 28
                        radius: Theme.radius - 6
                        color: Theme.cardBg

                        Column {
                            id: accentCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 12
                            Text {
                                text: "Accent color"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }
                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: Object.keys(Theme.accentMap)
                                    delegate: Rectangle {
                                        id: swatch
                                        required property string modelData
                                        readonly property bool selected: Theme.accentName === modelData
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: Theme.accentMap[modelData]
                                        border.width: selected ? 3 : 0
                                        border.color: Theme.fg

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            visible: swatch.selected
                                            name: "object-select-symbolic"
                                            size: 14
                                            tint: "#ffffff"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["gsettings", "set",
                                                "org.gnome.desktop.interface", "accent-color", swatch.modelData])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Blur"
                        subtitle: "Blurred wallpaper behind the top bar and dock"
                        ToggleSwitch { checked: win.o.blur; onToggled: v => win.o.blur = v }
                    }
                }

                // ================= Background =================
                Column {
                    visible: win.current.id === "background"
                    width: parent.width
                    spacing: 8

                    SettingsRow {
                        width: parent.width
                        title: "Wallpaper folder"
                        subtitle: Wallpaper.folder

                        IconButton {
                            icon: "folder-open-symbolic"
                            onClicked: folderDialog.open()
                        }
                        IconButton {
                            visible: win.o.wallpaperDir !== ""
                            icon: "edit-undo-symbolic"
                            onClicked: win.o.wallpaperDir = ""
                        }
                    }
                    FolderDialog {
                        id: folderDialog
                        title: "Wallpaper Folder"
                        currentFolder: "file://" + Wallpaper.folder
                        onAccepted: win.o.wallpaperDir = decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""))
                    }

                    WallpaperPicker {
                        width: parent.width
                        visible: win.visible && win.current.id === "background"
                    }
                }

                // ================= Dock =================
                Column {
                    visible: win.current.id === "dock"
                    width: parent.width
                    spacing: 8

                    SettingsRow {
                        width: parent.width
                        title: "Auto-hide"
                        subtitle: "Show the dock only when the pointer reaches the bottom edge, or on an empty workspace"
                        ToggleSwitch { checked: win.o.dockAutohide; onToggled: v => win.o.dockAutohide = v }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Icon size"
                        SegmentedControl {
                            width: 260
                            model: [
                                { label: "Small", value: "small" },
                                { label: "Default", value: "default" },
                                { label: "Large", value: "large" }
                            ]
                            current: win.o.dockIconSize
                            onSelected: v => win.o.dockIconSize = v
                        }
                    }
                }

                // ================= Power =================
                // Values are GNOME's (gsettings), shared with GNOME Settings → Power.
                Column {
                    visible: win.current.id === "power"
                    width: parent.width
                    spacing: 8

                    SectionLabel { text: "Power Saving" }
                    SettingsRow {
                        width: parent.width
                        title: "Dim screen"
                        subtitle: "Reduce brightness shortly before the screen blanks"
                        ToggleSwitch { checked: Power.idleDim; onToggled: v => Power.set(Power.powerSchema, "idle-dim", v) }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Screen blank"
                        subtitle: "Turn the screen off after a period of inactivity"
                        SegmentedControl {
                            width: 340
                            model: [
                                { label: "Never", value: "0" },
                                { label: "1 min", value: "60" },
                                { label: "2 min", value: "120" },
                                { label: "5 min", value: "300" },
                                { label: "10 min", value: "600" },
                                { label: "15 min", value: "900" }
                            ]
                            current: String(Power.idleDelay)
                            onSelected: v => Power.set(Power.sessionSchema, "idle-delay", v)
                        }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Automatic power saver"
                        subtitle: "Turn on Power Saver below 20% battery"
                        ToggleSwitch {
                            checked: Power.lowBatterySaver
                            onToggled: v => Power.set(Power.powerSchema, "power-saver-profile-on-low-battery", v)
                        }
                    }

                    SectionLabel { text: "Automatic Suspend"; topPadding: 12 }
                    Repeater {
                        model: [
                            { title: "On battery power", key: "battery" },
                            { title: "When plugged in", key: "ac" }
                        ]
                        delegate: SettingsRow {
                            id: suspendRow
                            required property var modelData
                            readonly property bool battery: modelData.key === "battery"
                            readonly property string type: battery ? Power.sleepBatteryType : Power.sleepAcType
                            readonly property int delay: battery ? Power.sleepBattery : Power.sleepAc
                            width: parent.width
                            title: modelData.title
                            SegmentedControl {
                                width: 300
                                model: [
                                    { label: "Off", value: "0" },
                                    { label: "15 min", value: "900" },
                                    { label: "20 min", value: "1200" },
                                    { label: "30 min", value: "1800" },
                                    { label: "1 hour", value: "3600" }
                                ]
                                current: suspendRow.type === "nothing" || suspendRow.delay === 0 ? "0" : String(suspendRow.delay)
                                // Off = type "nothing", like GNOME Settings.
                                onSelected: v => {
                                    var k = "sleep-inactive-" + suspendRow.modelData.key
                                    if (v === "0") {
                                        Power.set(Power.powerSchema, k + "-type", "nothing")
                                    } else {
                                        Power.set(Power.powerSchema, k + "-timeout", v)
                                        Power.set(Power.powerSchema, k + "-type", "suspend")
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Screen Lock"; topPadding: 12 }
                    SettingsRow {
                        width: parent.width
                        title: "Lock when the screen blanks"
                        subtitle: "The screen always locks before the computer sleeps"
                        ToggleSwitch { checked: Power.lockEnabled; onToggled: v => Power.set(Power.lockSchema, "lock-enabled", v) }
                    }
                }

                // ================= Night Light =================
                Column {
                    visible: win.current.id === "nightlight"
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        leftPadding: 4
                        bottomPadding: 4
                        wrapMode: Text.WordWrap
                        text: "Turn Night Light on or off in Quick Settings. Times use 24-hour HH:MM."
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    SettingsRow {
                        width: parent.width
                        title: "From"
                        TextField {
                            width: 90
                            text: win.o.nightFrom
                            validator: win.timeValidator
                            onCommitted: t => { if (t !== win.o.nightFrom) { win.o.nightFrom = t; Settings.restartNightLight() } }
                        }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "To"
                        TextField {
                            width: 90
                            text: win.o.nightTo
                            validator: win.timeValidator
                            onCommitted: t => { if (t !== win.o.nightTo) { win.o.nightTo = t; Settings.restartNightLight() } }
                        }
                    }
                    SettingsRow {
                        width: parent.width
                        title: "Color temperature"
                        subtitle: win.o.nightTemp + " K · lower is warmer"

                        SliderRow {
                            width: 240
                            icon: "night-light-symbolic"
                            showValue: false
                            readonly property int lo: 2500
                            readonly property int hi: 6000
                            value: (win.o.nightTemp - lo) / (hi - lo)
                            onValueEdited: v => win.o.nightTemp = Math.round((lo + v * (hi - lo)) / 100) * 100
                        }
                    }
                    // Apply the temperature once dragging settles, not on every step.
                    Timer {
                        id: tempApply
                        interval: 600
                        onTriggered: Settings.restartNightLight()
                    }
                    Connections {
                        target: win.o
                        function onNightTempChanged() { tempApply.restart() }
                    }
                }
            }
        }
    }
}
