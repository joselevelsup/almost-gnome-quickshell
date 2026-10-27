import Quickshell
import Quickshell.Wayland
import ".."
import QtQuick
import QtQuick.Layouts

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

        RowLayout {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            anchors.leftMargin: 8
            spacing: 4

            ActivitiesButton {}
            OverviewButton {}
            WindowMenuButton {}
        }

        // Reloj al centro real de la barra (no centrado entre los grupos
        // izq/der, que tienen anchos distintos).
        ClockWidget {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            anchors.rightMargin: 8
            spacing: 4

            Tray {}
            WallpaperButton {}
            StatusPill {}
        }
    }

    // Inhibidor de idle de "Caffeine": va atado a la barra (siempre visible)
    // porque Wayland exige una superficie para crearlo.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.enabled
    }

    DismissLayer {}
    // Esquinas calientes (hover con retardo, ver HotCorner.qml): la
    // superior izquierda abre el overview, la inferior izquierda la grilla
    // de aplicaciones.
    HotCorner { edge: "top"; action: "overview" }
    HotCorner { edge: "bottom"; action: "apps" }
    CalendarPopup {}
    QuickSettingsPanel {}
    WindowControlPopup {}
    OverviewPopup {}
    AltTabPopup {}
    SuperTabPopup {}
    WallpaperPopup {}
    NotificationToasts {}
    OsdPopup {}
    Dock {}
    ScreenshotPopup {}
}
