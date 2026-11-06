import Quickshell
import Quickshell.Wayland
import ".."
import QtQuick
import QtQuick.Layouts

// GNOME 50 top bar: workspace indicator on the left, clock in the center,
// system monitor, tray and system status on the right. Also hosts the background, every
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
        color: Theme.barBg

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
            spacing: 4

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

    Background {}
    DismissLayer {}
    // Hot corners (hover with a delay, see HotCorner.qml): top-left opens the
    // overview, bottom-left the app grid.
    HotCorner { edge: "top"; action: "overview" }
    HotCorner { edge: "bottom"; action: "apps" }
    CalendarPopup {}
    QuickSettingsPanel {}
    OverviewPopup {}
    AltTabPopup {}
    NotificationToasts {}
    OsdPopup {}
    Dock {}
    ScreenshotPopup {}
}
