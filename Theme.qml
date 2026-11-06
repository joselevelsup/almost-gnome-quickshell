pragma Singleton
import QtQuick
import Quickshell.Io

// GNOME 50 / Adwaita dark palette and visual tokens. Dark only; the accent
// color follows org.gnome.desktop.interface accent-color live.
QtObject {
    id: theme

    // ---------------------------------------------------------------
    // Layout
    // ---------------------------------------------------------------
    property int barHeight: 32
    property int radius: 18
    property int pillRadius: 999
    property int iconSize: 16
    property string fontFamily: "Adwaita Sans"
    property string monoFontFamily: "Adwaita Mono"

    // ---------------------------------------------------------------
    // Live accent (gsettings)
    // ---------------------------------------------------------------
    property string accentName: "blue"

    readonly property var accentMap: ({
        blue:   "#3584e4",
        teal:   "#2190a4",
        green:  "#3a944a",
        yellow: "#c88800",
        orange: "#ed5b00",
        red:    "#e62d42",
        pink:   "#d56199",
        purple: "#9141ac",
        slate:  "#6f8396"
    })
    readonly property color accent: accentMap[accentName] || accentMap.blue

    function withAlpha(colorStr, alpha) {
        var c = Qt.color(colorStr)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    // ---------------------------------------------------------------
    // Palette (Adwaita dark, opaque surfaces like GNOME Shell)
    // ---------------------------------------------------------------
    readonly property color fg:        "#ffffff"
    readonly property color fgDim:     "#9a9996"
    readonly property color danger:    "#e01b24"
    readonly property color ok:        "#26a269"

    // The GNOME top bar is solid black.
    readonly property color barBg:     "#000000"
    readonly property color popupBg:   "#2e2e32"
    readonly property color toastBg:   "#2e2e32"
    readonly property color border:    withAlpha("#ffffff", 0.08)
    readonly property color hoverBg:   withAlpha("#ffffff", 0.12)
    readonly property color activeBg:  withAlpha(theme.accent, 0.30)
    readonly property color trackBg:   withAlpha("#ffffff", 0.16)
    // Surface for buttons/tiles inside a popup (quick toggles when off, etc.).
    readonly property color cardBg:    withAlpha("#ffffff", 0.10)
    readonly property color cardHoverBg: withAlpha("#ffffff", 0.15)
    // Text/icons on top of the accent color (active tiles).
    readonly property color accentFg:  "#ffffff"
    readonly property color accentHover: Qt.lighter(theme.accent, 1.12)

    // ---------------------------------------------------------------
    // gsettings accent-color watcher
    // ---------------------------------------------------------------
    function _applyAccent(line) {
        var m = line.match(/'([a-z]+)'/)
        if (m) theme.accentName = m[1]
    }

    property Process accentInit: Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "accent-color"]
        running: true
        stdout: SplitParser { onRead: data => theme._applyAccent(data) }
    }
    property Process accentWatch: Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "accent-color"]
        running: true
        stdout: SplitParser { onRead: data => theme._applyAccent(data) }
    }
}
