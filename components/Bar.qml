import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import ".."
import QtQuick
import QtQuick.Layouts

// GNOME 50 top bar: workspace indicator on the left, clock in the center,
// system monitor, tray and system status on the right. Also hosts every
// popup, the dock and the OSD.
PanelWindow {
    id: bar
    property var modelData

    WlrLayershell.namespace: "quickshell:bar"
    anchors { top: true; left: true; right: true }
    exclusiveZone: Theme.barHeight
    focusable: false
    color: "transparent"

    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        // The bar stays lighter than the panels (0.35 at the default 0.7).
        color: Settings.options.blur ? Theme.withAlpha(Theme.barBg, Settings.options.blurOpacity / 2) : Theme.barBg

        Workspaces {
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        }

        // True center of the bar, not centered between the side groups.
        ClockWidget {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            anchors.rightMargin: 6
            spacing: 0

            SystemMonitor {}
            Tray {}
            StatusPill {}
        }
    }

    // Caffeine's idle inhibitor is tied to the bar (always visible) because
    // Wayland needs a surface to create it. It also covers playing media and
    // open mpv windows: umbriel ignores inhibitors from app windows.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.enabled || Mpris.players.values.some(p => p.isPlaying)
            || Umbriel.windows.some(w => w.appId === "mpv")
    }

    // Pinned to the bar's screen; otherwise the compositor picks one.
    DismissLayer { screen: bar.screen }
    // Bottom-left hot corner opens the app grid (see HotCorner.qml).
    HotCorner { screen: bar.screen; edge: "bottom" }
    // Built only while open to save memory. The app grid and screenshot
    // panel stay resident: the grid is slow to build, the panel keeps prefs.
    LazyLoader {
        active: PopupManager.current === "calendar"
        CalendarPopup { screen: bar.screen }
    }
    LazyLoader {
        active: PopupManager.current === "quicksettings"
        QuickSettingsPanel { screen: bar.screen }
    }
    AppGridPopup { screen: bar.screen }
    LazyLoader {
        active: Switcher.winActive
        AltTabPopup { screen: bar.screen }
    }
    NotificationToasts { screen: bar.screen }
    OsdPopup { screen: bar.screen }
    Dock { screen: bar.screen }
    ScreenshotPopup { screen: bar.screen }
}
