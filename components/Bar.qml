import Quickshell
import Quickshell.Wayland
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
        color: Settings.options.blur ? "transparent" : Theme.barBg

        BlurBackdrop { tint: Theme.withAlpha("#000000", 0.35) }

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
    // Wayland needs a surface to create it.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.enabled
    }

    // Pinned to the bar's screen; otherwise the compositor picks one.
    DismissLayer { screen: bar.screen }
    // Bottom-left hot corner opens the app grid (see HotCorner.qml).
    HotCorner { screen: bar.screen; edge: "bottom" }
    CalendarPopup { screen: bar.screen }
    QuickSettingsPanel { screen: bar.screen }
    AppGridPopup { screen: bar.screen }
    AltTabPopup { screen: bar.screen }
    NotificationToasts { screen: bar.screen }
    OsdPopup { screen: bar.screen }
    Dock { screen: bar.screen }
    ScreenshotPopup { screen: bar.screen }
}
